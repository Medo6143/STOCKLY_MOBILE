import 'dart:io';

import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_controls.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_billing_records.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/fake_backend/handlers/fake_invoices_handler.dart';
import 'package:stockly/core/fake_backend/seed/fake_billing_seed.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/time/clock.dart';

/// Fake B1–B6 (contract §12, ADR-0015): plans in the request language,
/// the subscription with today's scans, the Owner-only checkout with the
/// backend's validation order and `clientRequestId` idempotency (`201`
/// new, `200` repeat), a fake hosted checkout URL
/// (`https://fake.stockly.invalid/pay/{id}`, never opened) or a kiosk
/// reference, payments expiring on the fake clock, and the Owner-only
/// cancel. Only [settlePayment] (the debug panel, standing in for the
/// provider callback) makes a payment `Paid` or `Failed`.
final class FakeBillingHandler implements FakeHandler {
  new({
    required this._state,
    required this._config,
    required this._controls,
    required this._clock,
    required this._uuid,
    required this._problems,
    required this._authenticate,
  }) {
    if (_state.plans.isEmpty) {
      _state.plans.addAll(FakeBillingSeed.plans());
    }
  }

  final FakeBackendState _state;
  final FakeBackendConfig _config;
  final FakeBackendControls _controls;
  final Clock _clock;
  final UuidGenerator _uuid;
  final FakeProblems _problems;
  final FakeAccessToken? Function(FakeRequest request) _authenticate;

  static const String _payment = '${ApiPaths.billingPayments}/{id}';
  static const String _idParam = 'id';
  static const String _location = 'Location';
  static const String _currency = 'EGP';
  static const String _hostedCheckout = '${AppConfig.fakeApiBaseUrl}/pay/';
  static const String _declined = 'Declined by the issuer (fake provider).';
  static const int _defaultPage = 1;
  static const int _defaultPageSize = 20;
  static const int _maxPageSize = 100;
  static const int _moneyScale = 2;
  static const int _referenceBase = 700000000;
  static final RegExp _uuidPattern = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );
  static final RegExp _egyptianMobile = RegExp(r'^01[0125][0-9]{8}$');

  int _references = 0;

  @override
  List<FakeRoute> get routes => [
    FakeRoute('GET', ApiPaths.billingPlans, (r) => _guard(r, _plans)),
    FakeRoute(
      'GET',
      ApiPaths.billingSubscription,
      (r) => _guard(r, _subscription),
    ),
    FakeRoute(
      'POST',
      ApiPaths.billingCheckout,
      (r) => _guard(r, _checkout, ownerOnly: true),
    ),
    FakeRoute('GET', ApiPaths.billingPayments, (r) => _guard(r, _list)),
    FakeRoute('GET', _payment, (r) => _guard(r, _get)),
    FakeRoute(
      'POST',
      '$_payment/cancel',
      (r) => _guard(r, _cancel, ownerOnly: true),
    ),
  ];

  /// The scan quota of [shopId] today (B2 `effectiveDailyScanQuota`): 0
  /// when the debug panel used it up, else the configured override, else
  /// the plan's.
  int effectiveDailyScanQuota(String shopId) {
    if (_controls.scanQuotaExhausted) {
      return 0;
    }
    return _config.scanDailyQuota ?? _planOf(shopId).dailyScanQuota;
  }

  /// The provider's answer for [paymentId] (debug panel): paid or failed.
  /// A payment that is no longer pending stays as it is, except that a
  /// late success of a cancelled (expired) payment is honoured (contract
  /// B6). Returns `false` when nothing changed.
  bool settlePayment(String paymentId, {required bool paid}) {
    final payment = _state.payments.where((p) => p.id == paymentId).firstOrNull;
    if (payment == null) {
      return false;
    }
    _expire(payment);
    final settles =
        payment.isPending ||
        (paid && payment.status == FakePaymentStatuses.expired);
    if (!settles) {
      return false;
    }
    final now = _clock.now();
    if (paid) {
      payment
        ..status = FakePaymentStatuses.paid
        ..paidAt = now;
      final today = FakeCairoTime.dayOf(now);
      _subscriptionOf(payment.shopId)
        ..planId = payment.planId
        ..startsOn = today
        ..endsOn = _nextMonth(today);
    } else {
      payment
        ..status = FakePaymentStatuses.failed
        ..failureReason = _declined;
    }
    return true;
  }

  /// `401` without a valid token, `403 Shop.Suspended`, and `403
  /// Auth.Forbidden` for Staff on Owner-only endpoints (before any
  /// validation, like the backend's policy). The shop comes from the token
  /// only.
  FakeResponse _guard(
    FakeRequest request,
    FakeResponse Function(FakeRequest request, FakeAccessToken access) handle, {
    bool ownerOnly = false,
  }) {
    final access = _authenticate(request);
    final shop = access == null ? null : _state.shopById(access.shopId);
    if (access == null || shop == null) {
      return _error(request, ApiErrorCode.authUnauthenticated);
    }
    if (shop.status == FakeShopStatuses.suspended) {
      return _error(request, ApiErrorCode.shopSuspended);
    }
    if (ownerOnly &&
        _state.membership(access.userId, access.shopId)?.role !=
            FakeRoles.owner) {
      return _error(request, ApiErrorCode.authForbidden);
    }
    return handle(request, access);
  }

  // B1
  FakeResponse _plans(FakeRequest request, FakeAccessToken access) {
    final current = _planOf(access.shopId).id;
    final plans = _state.plans.where((p) => p.active).toList()
      ..sort((a, b) {
        if (a.isFree != b.isFree) {
          return a.isFree ? -1 : 1;
        }
        return a.monthlyPrice.compareTo(b.monthlyPrice);
      });
    return FakeResponse.list(HttpStatus.ok, [
      for (final plan in plans) _planJson(plan, request.language, current),
    ]);
  }

  // B2
  FakeResponse _subscription(FakeRequest request, FakeAccessToken access) {
    final shopId = access.shopId;
    final subscription = _subscriptionOf(shopId);
    final plan = _planOf(shopId);
    final today = FakeCairoTime.dayOf(_clock.now());
    final scansToday = (_state.acceptedScans[shopId] ?? const [])
        .where((at) => FakeCairoTime.dayOf(at) == today)
        .length;
    final pending = _paymentsOf(shopId).where((p) => p.isPending).toList();
    return FakeResponse.json(HttpStatus.ok, {
      'plan': _planJson(plan, request.language, plan.id),
      'startsOn': subscription.startsOn,
      'endsOn': subscription.endsOn,
      'effectiveDailyScanQuota': effectiveDailyScanQuota(shopId),
      'scansToday': scansToday,
      'memberCount': _state.memberships
          .where((m) => m.shopId == shopId && m.active)
          .length,
      'pendingPayment': pending.isEmpty
          ? null
          : _paymentJson(pending.last, request.language),
    });
  }

  // B3
  FakeResponse _checkout(FakeRequest request, FakeAccessToken access) {
    final json = request.jsonObject ?? const <String, Object?>{};
    final language = request.language;
    final errors = <String, List<String>>{};
    void uuid(String field) {
      final value = json[field];
      if (value is! String || !_uuidPattern.hasMatch(value)) {
        errors[field] = [
          if (value == null)
            FakeMessages.required(language)
          else
            FakeMessages.invalidValue(language),
        ];
      }
    }

    uuid('clientRequestId');
    uuid('planId');
    final method = json['method'];
    if (method is! String || !FakePaymentMethods.all.contains(method)) {
      errors['method'] = [
        if (method == null)
          FakeMessages.required(language)
        else
          FakeMessages.invalidValue(language),
      ];
    }
    final phone = json['walletPhone'];
    if (method == FakePaymentMethods.wallet) {
      if (phone == null || (phone is String && phone.isEmpty)) {
        errors['walletPhone'] = [FakeMessages.required(language)];
      } else if (phone is! String || !_egyptianMobile.hasMatch(phone)) {
        errors['walletPhone'] = [FakeMessages.invalidPhone(language)];
      }
    }
    if (errors.isNotEmpty) {
      return _problems.validation(request, errors);
    }
    final shopId = access.shopId;
    final clientRequestId = (json['clientRequestId']! as String).toLowerCase();
    final repeat = _paymentsOf(shopId)
        .where((p) => p.clientRequestId == clientRequestId)
        .firstOrNull;
    if (repeat != null) {
      return FakeResponse.json(HttpStatus.ok, _paymentJson(repeat, language));
    }
    final planId = (json['planId']! as String).toLowerCase();
    final plan = _state.plans.where((p) => p.id == planId).firstOrNull;
    if (plan == null) {
      return _error(request, ApiErrorCode.planNotFound);
    }
    if (!plan.active) {
      return _error(request, ApiErrorCode.planInactive);
    }
    if (plan.isFree) {
      return _error(request, ApiErrorCode.billingFreePlan);
    }
    if (_paymentsOf(shopId).any((p) => p.isPending)) {
      return _error(request, ApiErrorCode.billingPaymentPending);
    }
    final now = _clock.now();
    final id = _uuid.v4();
    final kiosk = method == FakePaymentMethods.kiosk;
    final payment = FakePayment(
      id: id,
      shopId: shopId,
      clientRequestId: clientRequestId,
      planId: plan.id,
      amount: plan.monthlyPrice,
      method: method! as String,
      checkoutUrl: kiosk ? null : '$_hostedCheckout$id',
      referenceNumber: kiosk ? '${_referenceBase + ++_references}' : null,
      expiresAt: now.add(kiosk ? _config.kioskExpiry : _config.checkoutExpiry),
      createdAt: now,
    );
    _state.payments.add(payment);
    return FakeResponse(
      HttpStatus.created,
      json: _paymentJson(payment, language),
      headers: {_location: '${ApiPaths.billingPayments}/$id'},
    );
  }

  // B4
  FakeResponse _get(FakeRequest request, FakeAccessToken access) {
    final payment = _paymentOf(access.shopId, request.params[_idParam]);
    return payment == null
        ? _error(request, ApiErrorCode.paymentNotFound)
        : FakeResponse.json(
            HttpStatus.ok,
            _paymentJson(payment, request.language),
          );
  }

  // B5
  FakeResponse _list(FakeRequest request, FakeAccessToken access) {
    final errors = <String, List<String>>{};
    final page = _int(request, ApiQuery.page, _defaultPage, errors);
    final pageSize = _int(request, ApiQuery.pageSize, _defaultPageSize, errors);
    if (page != null && page < 1) {
      errors[ApiQuery.page] = [FakeMessages.invalidValue(request.language)];
    }
    if (pageSize != null && (pageSize < 1 || pageSize > _maxPageSize)) {
      errors[ApiQuery.pageSize] = [FakeMessages.invalidValue(request.language)];
    }
    if (errors.isNotEmpty || page == null || pageSize == null) {
      return _problems.validation(request, errors);
    }
    final rows = _paymentsOf(access.shopId).reversed.toList();
    return FakeResponse.json(HttpStatus.ok, {
      'items': [
        for (final payment in rows.skip((page - 1) * pageSize).take(pageSize))
          _paymentJson(payment, request.language),
      ],
      'page': page,
      'pageSize': pageSize,
      'totalCount': rows.length,
    });
  }

  // B6
  FakeResponse _cancel(FakeRequest request, FakeAccessToken access) {
    final payment = _paymentOf(access.shopId, request.params[_idParam]);
    if (payment == null) {
      return _error(request, ApiErrorCode.paymentNotFound);
    }
    if (!payment.isPending) {
      return _error(request, ApiErrorCode.billingNotCancelable);
    }
    payment.status = FakePaymentStatuses.expired;
    return FakeResponse.json(
      HttpStatus.ok,
      _paymentJson(payment, request.language),
    );
  }

  /// The shop's subscription; a shop without one (registered after the
  /// seed) is put on the free plan from today.
  FakeSubscription _subscriptionOf(String shopId) {
    final existing = _state.subscriptions
        .where((s) => s.shopId == shopId)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }
    final created = FakeSubscription(
      shopId: shopId,
      planId: _state.plans.firstWhere((p) => p.isFree).id,
      startsOn: FakeCairoTime.dayOf(_clock.now()),
      endsOn: null,
    );
    _state.subscriptions.add(created);
    return created;
  }

  FakePlan _planOf(String shopId) {
    final planId = _subscriptionOf(shopId).planId;
    return _state.plans.firstWhere((p) => p.id == planId);
  }

  /// The payments of [shopId], oldest first, after expiring the ones whose
  /// `expiresAt` passed on the fake clock.
  List<FakePayment> _paymentsOf(String shopId) => [
    for (final payment in _state.payments)
      if (payment.shopId == shopId) _expire(payment),
  ];

  FakePayment? _paymentOf(String shopId, String? id) =>
      _paymentsOf(shopId).where((p) => p.id == id).firstOrNull;

  FakePayment _expire(FakePayment payment) {
    if (payment.isPending && !_clock.now().isBefore(payment.expiresAt)) {
      payment.status = FakePaymentStatuses.expired;
    }
    return payment;
  }

  /// The same day next month (the last day when it does not exist).
  static String _nextMonth(String day) {
    final parts = day.split('-').map(int.parse).toList();
    final (year, month, date) = (parts[0], parts[1], parts[2]);
    final lastDay = DateTime.utc(year, month + 2, 0).day;
    final next = DateTime.utc(year, month + 1, date > lastDay ? lastDay : date);
    return next.toIso8601String().substring(0, 10);
  }

  int? _int(
    FakeRequest request,
    String name,
    int fallback,
    Map<String, List<String>> errors,
  ) {
    final raw = request.query[name];
    if (raw == null) {
      return fallback;
    }
    final value = int.tryParse(raw);
    if (value == null) {
      errors[name] = [FakeMessages.invalidValue(request.language)];
    }
    return value;
  }

  FakeResponse _error(FakeRequest request, ApiErrorCode code) =>
      _problems.problem(request, FakeProblems.statusOf(code), code);

  static String _iso(DateTime value) => value.toUtc().toIso8601String();

  Map<String, Object?> _planJson(
    FakePlan plan,
    String language,
    String currentPlanId,
  ) => {
    'id': plan.id,
    'code': plan.code,
    'name': plan.nameIn(language),
    'monthlyPrice': plan.monthlyPrice.toStringAsFixed(_moneyScale),
    'dailyScanQuota': plan.dailyScanQuota,
    'maxMembers': plan.maxMembers,
    'isFree': plan.isFree,
    'isCurrent': plan.id == currentPlanId,
  };

  Map<String, Object?> _paymentJson(FakePayment payment, String language) {
    final plan = _state.plans.firstWhere((p) => p.id == payment.planId);
    final paidAt = payment.paidAt;
    return {
      'id': payment.id,
      'clientRequestId': payment.clientRequestId,
      'planId': payment.planId,
      'planName': plan.nameIn(language),
      'amount': payment.amount.toStringAsFixed(_moneyScale),
      'currency': _currency,
      'method': payment.method,
      'status': payment.status,
      'checkoutUrl': payment.checkoutUrl,
      'referenceNumber': payment.referenceNumber,
      'expiresAt': _iso(payment.expiresAt),
      'failureReason': payment.failureReason,
      'createdAt': _iso(payment.createdAt),
      'paidAt': paidAt == null ? null : _iso(paidAt),
    };
  }
}
