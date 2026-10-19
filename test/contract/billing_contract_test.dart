import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_billing_records.dart';
import 'package:stockly/core/fake_backend/seed/fake_billing_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:stockly/features/billing/data/models/billing_dtos.dart';
import 'package:stockly/features/billing/data/models/billing_mapper.dart';
import 'package:stockly/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';

import '../helpers/fake_app.dart';
import '../helpers/products_doubles.dart' show errOf, okValue;
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

/// Contract B1–B6 (v1.7 §12, ADR-0015) against the fake backend: status
/// codes, Owner-only checkout and cancel, the validation order,
/// `clientRequestId` idempotency, the hosted checkout URL and the kiosk
/// reference, expiry on the fake clock, the provider's answer through the
/// debug hook, and the JSON shapes of the contract fixtures.
void main() {
  late FakeClock clock;
  late FakeBackendState state;
  late FakeBackendAdapter adapter;
  late Dio dio;
  late String owner;
  late String staff;
  var serial = 0;

  Future<void> start({FakeBackendConfig? config}) async {
    clock = FakeClock();
    state = FakeSeed.pharmacy(clock.now());
    adapter = fakeBackend(
      clock: clock,
      state: state,
      config: config ?? const FakeBackendConfig(latency: Duration.zero),
    );
    dio = rawDio(adapter)..options.validateStatus = ((_) => true);
    owner = (await loginOn(adapter)).accessToken;
    staff = (await loginOn(adapter, email: FakeSeed.staffEmail)).accessToken;
  }

  setUp(start);

  Options auth({String? token, String language = 'en'}) => Options(
    headers: {
      HttpHeaderNames.acceptLanguage: language,
      HttpHeaderNames.authorization:
          '${HttpHeaderNames.bearerPrefix}${token ?? owner}',
    },
  );

  String newId() {
    serial++;
    final suffix = serial.toRadixString(16).padLeft(12, '0');
    return '0192f0a0-6c1e-7b3a-9d2e-$suffix';
  }

  Map<String, Object?> json(Response<Object?> response) =>
      response.data! as Map<String, Object?>;

  void expectProblem(Response<Object?> response, int status, String code) {
    expect(response.statusCode, status, reason: '${response.data}');
    expect(
      response.headers.value(Headers.contentTypeHeader),
      startsWith('application/problem+json'),
    );
    expect(json(response)['code'], code);
  }

  Future<Response<Object?>> checkout({
    String? clientRequestId,
    Object? planId = FakeBillingSeed.basicPlanId,
    Object? method = 'Card',
    Object? walletPhone,
    String? token,
  }) => dio.post<Object?>(
    ApiPaths.billingCheckout,
    data: {
      'clientRequestId': clientRequestId ?? newId(),
      'planId': planId,
      'method': method,
      'walletPhone': walletPhone,
    },
    options: auth(token: token),
  );

  Future<Response<Object?>> get(String path, {String? token, String? lang}) =>
      dio.get<Object?>(
        path,
        options: auth(token: token, language: lang ?? 'en'),
      );

  group('B1 GET /api/billing/plans', () {
    test('FreeFirstThenByPrice_CurrentMarked_InTheRequestLanguage', () async {
      final en = await get(ApiPaths.billingPlans);
      final ar = await get(ApiPaths.billingPlans, lang: 'ar');

      expect(en.statusCode, HttpStatus.ok);
      final plans = (en.data! as List<Object?>).cast<Map<String, Object?>>();
      for (final plan in plans) {
        expectSameShape(plan, fixture('billing_plan'), enums: billingEnums);
      }
      expect(plans.map((p) => p['code']), ['free', 'basic', 'pro']);
      expect(plans.map((p) => p['isCurrent']), [true, false, false]);
      expect(plans.first['isFree'], isTrue);
      expect(plans.first['monthlyPrice'], '0.00');
      expect(plans[1]['name'], 'Basic');
      final arPlans = (ar.data! as List<Object?>).cast<Map<String, Object?>>();
      expect(arPlans[1]['name'], 'الأساسية');
    });

    test('InactivePlan_NotListed', () async {
      state.plans.last.active = false;

      final plans = (await get(ApiPaths.billingPlans)).data! as List<Object?>;

      expect(plans, hasLength(2));
    });

    test('NoToken_401', () async {
      final response = await dio.get<Object?>(ApiPaths.billingPlans);
      expectProblem(
        response,
        HttpStatus.unauthorized,
        ApiErrorCode.authUnauthenticated.wire,
      );
    });
  });

  group('B2 GET /api/billing/subscription', () {
    test('FreePlan_TodayScans_Members_NoPending', () async {
      final shopId = state.shops.single.id;
      state.acceptedScans[shopId] = [
        clock.now(),
        clock.now(),
        clock.now().subtract(const Duration(days: 2)),
      ];

      final response = await get(ApiPaths.billingSubscription, token: staff);

      expect(response.statusCode, HttpStatus.ok);
      final body = json(response);
      expectSameShape(
        body,
        fixture('subscription_summary'),
        enums: billingEnums,
      );
      expect((body['plan']! as Map)['code'], 'free');
      expect(body['endsOn'], isNull);
      expect(body['scansToday'], 2);
      expect(body['effectiveDailyScanQuota'], FakeBillingSeed.freeDailyScans);
      expect(body['memberCount'], 2);
      expect(body['pendingPayment'], isNull);
    });

    test('QuotaUsedUp_0_Override_ConfigValue', () async {
      adapter.controls.scanQuotaExhausted = true;
      expect(
        json(
          await get(ApiPaths.billingSubscription),
        )['effectiveDailyScanQuota'],
        0,
      );
      await start(
        config: const FakeBackendConfig(
          latency: Duration.zero,
          scanDailyQuota: 3,
        ),
      );
      expect(
        json(
          await get(ApiPaths.billingSubscription),
        )['effectiveDailyScanQuota'],
        3,
      );
    });

    test('PendingPayment_TheNewestPendingOne', () async {
      final created = json(await checkout(method: 'Kiosk'));

      final body = json(await get(ApiPaths.billingSubscription));

      expectSameShape(
        body,
        fixture('subscription_summary'),
        enums: billingEnums,
      );
      expect((body['pendingPayment']! as Map)['id'], created['id']);
    });
  });

  group('B3 POST /api/billing/checkout', () {
    test('Card_201WithLocationAndAHostedPage', () async {
      final response = await checkout();

      expect(
        response.statusCode,
        HttpStatus.created,
        reason: '${response.data}',
      );
      final body = json(response);
      expectSameShape(body, fixture('payment'), enums: billingEnums);
      expect(
        response.headers.value('location'),
        '${ApiPaths.billingPayments}/${body['id']}',
      );
      expect(body['status'], 'Pending');
      expect(body['amount'], '150.00');
      expect(body['currency'], 'EGP');
      expect(
        body['checkoutUrl'],
        'https://fake.stockly.invalid/pay/${body['id']}',
      );
      expect(body['referenceNumber'], isNull);
      expect(
        DateTime.parse(body['expiresAt']! as String),
        clock.now().add(FakeBackendConfig.defaultCheckoutExpiry),
      );
    });

    test('Kiosk_AReferenceAndNoPage', () async {
      final body = json(await checkout(method: 'Kiosk'));

      expect(body['checkoutUrl'], isNull);
      expect(body['referenceNumber'], matches(RegExp(r'^\d{9}$')));
      expect(
        DateTime.parse(body['expiresAt']! as String),
        clock.now().add(FakeBackendConfig.defaultKioskExpiry),
      );
    });

    test('Wallet_PhoneRequiredAndEgyptian', () async {
      for (final phone in [
        null,
        '',
        '0101234567',
        '01312345678',
        '٠١٠١٢٣٤٥٦٧٨',
      ]) {
        final response = await checkout(method: 'Wallet', walletPhone: phone);
        expectProblem(
          response,
          HttpStatus.badRequest,
          ApiErrorCode.validationFailed.wire,
        );
        expect(
          (json(response)['errors']! as Map).keys,
          contains('walletPhone'),
          reason: '$phone',
        );
      }
      final ok = await checkout(method: 'Wallet', walletPhone: '01012345678');
      expect(ok.statusCode, HttpStatus.created);
      expect(json(ok)['checkoutUrl'], isNotNull);
    });

    test('PhoneIgnoredForCard', () async {
      final response = await checkout(walletPhone: 'not a phone');
      expect(response.statusCode, HttpStatus.created);
    });

    test('Shape_400ValidationFailed', () async {
      for (final (planId, method, field) in [
        (null, 'Card', 'planId'),
        ('x', 'Card', 'planId'),
        (FakeBillingSeed.basicPlanId, 'Cash', 'method'),
        (FakeBillingSeed.basicPlanId, null, 'method'),
      ]) {
        final response = await checkout(planId: planId, method: method);
        expectProblem(
          response,
          HttpStatus.badRequest,
          ApiErrorCode.validationFailed.wire,
        );
        expect((json(response)['errors']! as Map).keys, contains(field));
      }
      final noId = await dio.post<Object?>(
        ApiPaths.billingCheckout,
        data: {'planId': FakeBillingSeed.basicPlanId, 'method': 'Card'},
        options: auth(),
      );
      expect((json(noId)['errors']! as Map).keys, contains('clientRequestId'));
    });

    test('Repeat_200TheSamePayment_NothingNew', () async {
      final id = newId();
      final first = await checkout(clientRequestId: id);

      final repeat = await checkout(
        clientRequestId: id.toUpperCase(),
        method: 'Kiosk',
      );

      expect(repeat.statusCode, HttpStatus.ok);
      expect(json(repeat), json(first));
      expect(state.payments, hasLength(1));
    });

    test('Staff_403BeforeValidation', () async {
      final response = await checkout(token: staff, method: null);
      expectProblem(
        response,
        HttpStatus.forbidden,
        ApiErrorCode.authForbidden.wire,
      );
      expect(state.payments, isEmpty);
    });

    test('PlanRules_FreeInactiveUnknown', () async {
      expectProblem(
        await checkout(planId: FakeBillingSeed.freePlanId),
        HttpStatus.badRequest,
        ApiErrorCode.billingFreePlan.wire,
      );
      expectProblem(
        await checkout(planId: newId()),
        HttpStatus.notFound,
        ApiErrorCode.planNotFound.wire,
      );
      state.plans.last.active = false;
      expectProblem(
        await checkout(planId: FakeBillingSeed.proPlanId),
        HttpStatus.badRequest,
        ApiErrorCode.planInactive.wire,
      );
    });

    test('PendingNotExpired_409_ThenAllowedAfterExpiry', () async {
      await checkout();

      expectProblem(
        await checkout(method: 'Kiosk'),
        HttpStatus.conflict,
        ApiErrorCode.billingPaymentPending.wire,
      );
      clock.advance(FakeBackendConfig.defaultCheckoutExpiry);
      // The access token expired with the hour; sign in again.
      owner = (await loginOn(adapter)).accessToken;
      expect((await checkout(method: 'Kiosk')).statusCode, HttpStatus.created);
      expect(state.payments.first.status, FakePaymentStatuses.expired);
    });

    test('ProviderDownOrMethodOff_502And400_NothingCreated', () async {
      adapter.controls.failNextWith = ApiErrorCode.billingProviderUnavailable;
      expectProblem(
        await checkout(),
        HttpStatus.badGateway,
        ApiErrorCode.billingProviderUnavailable.wire,
      );
      adapter.controls.failNextWith = ApiErrorCode.billingMethodUnavailable;
      expectProblem(
        await checkout(),
        HttpStatus.badRequest,
        ApiErrorCode.billingMethodUnavailable.wire,
      );
      expect(state.payments, isEmpty);
    });
  });

  group('B4 GET /api/billing/payments/{id}', () {
    test('Owner_Staff_200_UnknownOrOtherShop_404', () async {
      final id = json(await checkout())['id']! as String;

      final mine = await get(ApiPaths.billingPayment(id), token: staff);
      expect(mine.statusCode, HttpStatus.ok);
      expectSameShape(json(mine), fixture('payment'), enums: billingEnums);
      expectProblem(
        await get(ApiPaths.billingPayment(newId())),
        HttpStatus.notFound,
        ApiErrorCode.paymentNotFound.wire,
      );
      final other = state.payments.single;
      state.payments
        ..clear()
        ..add(
          FakePayment(
            id: other.id,
            shopId: newId(),
            clientRequestId: other.clientRequestId,
            planId: other.planId,
            amount: other.amount,
            method: other.method,
            checkoutUrl: other.checkoutUrl,
            referenceNumber: null,
            expiresAt: other.expiresAt,
            createdAt: other.createdAt,
          ),
        );
      expectProblem(
        await get(ApiPaths.billingPayment(id)),
        HttpStatus.notFound,
        ApiErrorCode.paymentNotFound.wire,
      );
    });

    test('Expiry_OnTheFakeClock', () async {
      final id = json(await checkout())['id']! as String;
      clock.advance(FakeBackendConfig.defaultCheckoutExpiry);
      // The access token expired with the hour; sign in again.
      owner = (await loginOn(adapter)).accessToken;

      expect(json(await get(ApiPaths.billingPayment(id)))['status'], 'Expired');
    });
  });

  group('B5 GET /api/billing/payments', () {
    test('NewestFirst_Paged', () async {
      final first = json(await checkout())['id'];
      adapter.settlePayment(first! as String, paid: false);
      final second = json(await checkout(method: 'Kiosk'))['id'];

      final page = await get('${ApiPaths.billingPayments}?page=1&pageSize=1');

      expect(page.statusCode, HttpStatus.ok);
      final body = json(page);
      expectSameShape(body, fixture('payment_page'), enums: billingEnums);
      expect(body['totalCount'], 2);
      expect((body['items']! as List).map((p) => (p as Map)['id']), [second]);
      final next = json(
        await get('${ApiPaths.billingPayments}?page=2&pageSize=1'),
      );
      expect((next['items']! as List).map((p) => (p as Map)['id']), [first]);
    });

    test('PageSizeOver100_400', () async {
      expectProblem(
        await get('${ApiPaths.billingPayments}?pageSize=101'),
        HttpStatus.badRequest,
        ApiErrorCode.validationFailed.wire,
      );
    });
  });

  group('B6 POST /api/billing/payments/{id}/cancel', () {
    test('Pending_200Expired_ThenNotCancelable', () async {
      final id = json(await checkout())['id']! as String;
      Future<Response<Object?>> cancel({String? token}) => dio.post<Object?>(
        ApiPaths.billingPaymentCancel(id),
        options: auth(token: token),
      );

      expectProblem(
        await cancel(token: staff),
        HttpStatus.forbidden,
        ApiErrorCode.authForbidden.wire,
      );
      final cancelled = await cancel();
      expect(cancelled.statusCode, HttpStatus.ok);
      expectSameShape(json(cancelled), fixture('payment'), enums: billingEnums);
      expect(json(cancelled)['status'], 'Expired');
      expectProblem(
        await cancel(),
        HttpStatus.conflict,
        ApiErrorCode.billingNotCancelable.wire,
      );
      expectProblem(
        await dio.post<Object?>(
          ApiPaths.billingPaymentCancel(newId()),
          options: auth(),
        ),
        HttpStatus.notFound,
        ApiErrorCode.paymentNotFound.wire,
      );
    });
  });

  group('Provider answer (debug hook standing in for the callback)', () {
    test('Paid_SwitchesThePlanUntilNextMonth', () async {
      final id = json(await checkout())['id']! as String;

      expect(adapter.settlePayment(id, paid: true), isTrue);

      final payment = json(await get(ApiPaths.billingPayment(id)));
      expect(payment['status'], 'Paid');
      expect(payment['paidAt'], isNotNull);
      final subscription = json(await get(ApiPaths.billingSubscription));
      expect((subscription['plan']! as Map)['code'], 'basic');
      expect(subscription['startsOn'], '2026-10-12');
      expect(subscription['endsOn'], '2026-11-12');
      expect(subscription['pendingPayment'], isNull);
      final plans = (await get(ApiPaths.billingPlans)).data! as List<Object?>;
      expect(plans.map((p) => (p! as Map)['isCurrent']), [false, true, false]);
      expect(adapter.settlePayment(id, paid: false), isFalse);
    });

    test('Failed_WithAReason', () async {
      final id = json(await checkout())['id']! as String;

      adapter.settlePayment(id, paid: false);

      final payment = json(await get(ApiPaths.billingPayment(id)));
      expect(payment['status'], 'Failed');
      expect(payment['failureReason'], isNotEmpty);
    });

    test('LateSuccessOfACancelledPayment_Honoured', () async {
      final id = json(await checkout())['id']! as String;
      await dio.post<Object?>(
        ApiPaths.billingPaymentCancel(id),
        options: auth(),
      );

      expect(adapter.settlePayment(id, paid: true), isTrue);
      expect(json(await get(ApiPaths.billingPayment(id)))['status'], 'Paid');
    });
  });

  group('Billing data layer over the fake backend', () {
    late BillingRepositoryImpl repository;

    setUp(() {
      final client = rawDio(adapter)
        ..options.headers[HttpHeaderNames.authorization] =
            '${HttpHeaderNames.bearerPrefix}$owner';
      repository = BillingRepositoryImpl(BillingRemoteDataSource(client));
    });

    CheckoutRequest request(String id, PaymentMethod method) => CheckoutRequest(
      clientRequestId: id,
      planId: FakeBillingSeed.basicPlanId,
      method: method,
      walletPhone: method == PaymentMethod.wallet ? '01012345678' : null,
    );

    test('RequestBody_MatchesTheContractFixture', () {
      final body = request(newId(), PaymentMethod.wallet).toDto().toJson();

      expectSameShape(body, fixture('checkout_request'), enums: billingEnums);
      expect(body['method'], 'Wallet');
      expect(
        request(newId(), PaymentMethod.card).toDto().toJson(),
        containsPair('walletPhone', null),
      );
    });

    test('Fixtures_ParseIntoEntities', () {
      final summary = SubscriptionSummaryDto.fromJson(
        fixture('subscription_summary'),
      ).toEntity();
      expect(summary.plan.isFree, isTrue);
      expect(summary.startsOn, const CalendarDate(2026, 10, 1));
      expect(summary.pendingPayment?.method, PaymentMethod.kiosk);
      final payment = PaymentDto.fromJson(fixture('payment')).toEntity();
      expect(payment.amount, Money.fromApi('150.00'));
      expect(payment.status, PaymentStatus.pending);
      expect(
        () =>
            PaymentDto.fromJson({...fixture('payment'), 'status': 'Refunded'})
                .toEntity(),
        throwsFormatException,
      );
    });

    test('Plans_Subscription_Checkout_Get_List_Cancel', () async {
      final plans = okValue(await repository.getPlans());
      expect(plans.map((p) => p.isCurrent), [true, false, false]);
      final id = newId();
      final created = okValue(
        await repository.checkout(request(id, PaymentMethod.kiosk)),
      );
      final repeat = okValue(
        await repository.checkout(request(id, PaymentMethod.kiosk)),
      );
      expect(repeat.id, created.id);
      expect(created.referenceNumber, isNotNull);
      final summary = okValue(await repository.getSubscription());
      expect(summary.pendingPayment?.id, created.id);
      expect(okValue(await repository.getPayment(created.id)).id, created.id);
      final page = okValue(await repository.getPayments(page: 1, pageSize: 20));
      expect(page.items.single.id, created.id);
      final cancelled = okValue(await repository.cancelPayment(created.id));
      expect(cancelled.status, PaymentStatus.expired);
      final again = errOf(await repository.cancelPayment(created.id));
      expect(again, isA<ConflictFailure>());
      expect(
        (again as ConflictFailure).code,
        ApiErrorCode.billingNotCancelable,
      );
    });

    test('ProviderUnavailable_ServerFailureWithItsCode', () async {
      adapter.controls.failNextWith = ApiErrorCode.billingProviderUnavailable;

      final failure = errOf(
        await repository.checkout(request(newId(), PaymentMethod.card)),
      );

      expect(failure, isA<ServerFailure>());
      expect(
        (failure as ServerFailure).code,
        ApiErrorCode.billingProviderUnavailable,
      );
    });
  });
}
