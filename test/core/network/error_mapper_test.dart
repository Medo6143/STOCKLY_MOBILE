import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/network/error_mapper.dart';

/// Design §4.5 table, written out independently of the mapper.
final Map<ApiErrorCode, Type> _expected = {
  ApiErrorCode.validationFailed: ValidationFailure,
  ApiErrorCode.serverUnexpected: ServerFailure,
  ApiErrorCode.httpNotFound: NotFoundFailure,
  ApiErrorCode.httpMethodNotAllowed: ServerFailure,
  ApiErrorCode.httpUnsupportedMediaType: ServerFailure,
  ApiErrorCode.authUnauthenticated: SessionEndedFailure,
  ApiErrorCode.authForbidden: ForbiddenFailure,
  ApiErrorCode.authEmailTaken: ConflictFailure,
  ApiErrorCode.authInvalidCredentials: InvalidCredentialsFailure,
  ApiErrorCode.authNoActiveShop: ForbiddenFailure,
  ApiErrorCode.authInvalidRefreshToken: SessionEndedFailure,
  ApiErrorCode.authRefreshTokenReused: SessionEndedFailure,
  ApiErrorCode.authLockedOut: AccountLockedFailure,
  ApiErrorCode.authTooManyRequests: AuthRateLimitedFailure,
  ApiErrorCode.shopNameRequired: InvalidInputFailure,
  ApiErrorCode.shopUnknownType: InvalidInputFailure,
  ApiErrorCode.shopSuspended: ShopSuspendedFailure,
  ApiErrorCode.productNotFound: NotFoundFailure,
  ApiErrorCode.productNameRequired: InvalidInputFailure,
  ApiErrorCode.productArchived: ConflictFailure,
  ApiErrorCode.productDuplicateBarcode: ConflictFailure,
  ApiErrorCode.productOpeningStockOwnerOnly: ForbiddenFailure,
  ApiErrorCode.productUnitNotFound: NotFoundFailure,
  ApiErrorCode.productUnitNameRequired: InvalidInputFailure,
  ApiErrorCode.productUnitDuplicateName: ConflictFailure,
  ApiErrorCode.productUnitDuplicateBarcode: ConflictFailure,
  ApiErrorCode.productUnitBaseUnitCannotBeRemoved: InvalidInputFailure,
  ApiErrorCode.productUnitBaseUnitFactorFixed: InvalidInputFailure,
  ApiErrorCode.productUnitInUse: ConflictFailure,
  ApiErrorCode.precisionTooManyDecimals: InvalidInputFailure,
  ApiErrorCode.precisionNegative: InvalidInputFailure,
  ApiErrorCode.precisionNotPositive: InvalidInputFailure,
  ApiErrorCode.precisionOutOfRange: InvalidInputFailure,
  ApiErrorCode.stockZeroChange: InvalidInputFailure,
  ApiErrorCode.stockNoteRequired: InvalidInputFailure,
  ApiErrorCode.invoiceNotFound: NotFoundFailure,
  ApiErrorCode.invoiceImageRequired: InvalidInputFailure,
  ApiErrorCode.invoiceUnsupportedImageType: InvalidInputFailure,
  ApiErrorCode.invoiceImageTooLarge: PayloadTooLargeFailure,
  ApiErrorCode.invoiceNotEditable: ConflictFailure,
  ApiErrorCode.invoiceNotConfirmable: ConflictFailure,
  ApiErrorCode.invoiceLineProductRequired: InvalidInputFailure,
  ApiErrorCode.invoiceUnitNotOfProduct: InvalidInputFailure,
  ApiErrorCode.scanRateLimited: ScanRateLimitedFailure,
  ApiErrorCode.scanDailyQuotaExceeded: ScanQuotaExceededFailure,
  ApiErrorCode.saleNotFound: NotFoundFailure,
  ApiErrorCode.saleArchivedProduct: InvalidInputFailure,
  ApiErrorCode.saleUnitNotOfProduct: InvalidInputFailure,
};

/// Contract §9 codes the app can receive (excluding the `Stock.*` movement
/// rules, which arrive as `500 Server.Unexpected`, and the
/// `Stock.NegativeBalance` warning).
const List<String> _contractCodes = [
  'Validation.Failed', 'Server.Unexpected', 'Http.NotFound', //
  'Http.MethodNotAllowed', 'Http.UnsupportedMediaType', //
  'Auth.Unauthenticated', 'Auth.Forbidden', 'Auth.EmailTaken', //
  'Auth.InvalidCredentials', 'Auth.NoActiveShop', //
  'Auth.InvalidRefreshToken', 'Auth.RefreshTokenReused', //
  'Auth.LockedOut', 'Auth.TooManyRequests', //
  'Shop.NameRequired', 'Shop.UnknownType', 'Shop.Suspended', //
  'Product.NotFound', 'Product.NameRequired', 'Product.Archived', //
  'Product.DuplicateBarcode', 'Product.OpeningStockOwnerOnly', //
  'ProductUnit.NotFound', 'ProductUnit.NameRequired', //
  'ProductUnit.DuplicateName', 'ProductUnit.DuplicateBarcode', //
  'ProductUnit.BaseUnitCannotBeRemoved', 'ProductUnit.BaseUnitFactorFixed', //
  'ProductUnit.InUse', 'Precision.TooManyDecimals', 'Precision.Negative', //
  'Precision.NotPositive', 'Precision.OutOfRange', 'Stock.ZeroChange', //
  'Stock.NoteRequired', 'Invoice.NotFound', 'Invoice.ImageRequired', //
  'Invoice.UnsupportedImageType', 'Invoice.ImageTooLarge', //
  'Invoice.NotEditable', 'Invoice.NotConfirmable', //
  'Invoice.LineProductRequired', 'Invoice.UnitNotOfProduct', //
  'Scan.RateLimited', 'Scan.DailyQuotaExceeded', 'Sale.NotFound', //
  'Sale.ArchivedProduct', 'Sale.UnitNotOfProduct',
];

Response<Object?> _response(
  int status,
  Object? data, {
  Map<String, List<String>> headers = const {},
}) => Response<Object?>(
  requestOptions: RequestOptions(path: '/api/x'),
  statusCode: status,
  data: data,
  headers: Headers.fromMap(headers),
);

Map<String, Object?> _problem(String code, {int status = 400}) => {
  'type': 'https://tools.ietf.org/html/rfc9110',
  'title': 'Ignored',
  'status': status,
  'detail': 'Ignored',
  'code': code,
  'traceId': '00-abc-00',
  'correlationId': 'cid-1',
};

void main() {
  test('ApiErrorCode_CoversEveryContractCode_AndNothingElse', () {
    expect(
      ApiErrorCode.values.map((c) => c.wire).toSet(),
      _contractCodes.toSet(),
    );
    for (final wire in _contractCodes) {
      expect(ApiErrorCode.fromWire(wire)?.wire, wire);
    }
    expect(ApiErrorCode.fromWire('Stock.NegativeBalance'), isNull);
  });

  test('failureForCode_EveryCode_MapsToItsFailureType', () {
    expect(_expected.keys.toSet(), ApiErrorCode.values.toSet());
    const info = ApiProblemInfo(status: 400);
    for (final code in ApiErrorCode.values) {
      final failure = failureForCode(code, info);
      expect(failure.runtimeType, _expected[code], reason: code.wire);
      expect(failure.code, code);
      expect(failure.info, info);
    }
  });

  test('mapErrorResponse_ProblemDetails_CopiesCodeAndReference', () {
    final failure = mapErrorResponse(
      _response(404, _problem('Product.NotFound', status: 404)),
    );
    expect(failure, isA<NotFoundFailure>());
    final info = (failure as NotFoundFailure).info;
    expect(info.status, 404);
    expect(info.traceId, '00-abc-00');
    expect(info.correlationId, 'cid-1');
    expect(info.reference, '00-abc-00');
  });

  test('mapErrorResponse_StringBody_IsDecoded', () {
    final failure = mapErrorResponse(
      _response(409, '{"status":409,"code":"Auth.EmailTaken"}'),
    );
    expect(failure, isA<ConflictFailure>());
  });

  test('mapErrorResponse_ValidationFailed_KeepsFieldErrors', () {
    final failure = mapErrorResponse(
      _response(400, {
        ..._problem('Validation.Failed'),
        'errors': {
          'items[2].quantity': ['Too many decimals'],
        },
      }),
    );
    expect((failure as ValidationFailure).fieldErrors, {
      'items[2].quantity': ['Too many decimals'],
    });
  });

  test('mapErrorResponse_UnknownCode_IsUnknownApiFailureWithRawCode', () {
    final failure = mapErrorResponse(_response(400, _problem('Something.New')));
    expect(failure, isA<UnknownApiFailure>());
    expect((failure as UnknownApiFailure).rawCode, 'Something.New');
    expect(failure.info.traceId, '00-abc-00');
  });

  test('mapErrorResponse_NonProblemBody_IsUnknownWithHeaderCorrelation', () {
    for (final body in <Object?>[
      '<html>Bad gateway</html>',
      '',
      null,
      ['not', 'an', 'object'],
      {'title': 'no code'},
    ]) {
      final failure = mapErrorResponse(
        _response(
          502,
          body,
          headers: {
            'x-correlation-id': ['cid-header'],
          },
        ),
      );
      expect(failure, isA<UnknownApiFailure>(), reason: '$body');
      final unknown = failure as UnknownApiFailure;
      expect(unknown.info.status, 502);
      expect(unknown.info.correlationId, 'cid-header');
      expect(unknown.rawCode, isNull);
    }
  });

  test('mapErrorResponse_RateLimited_UsesRetryAfterHeader', () {
    final failure = mapErrorResponse(
      _response(
        429,
        _problem('Scan.RateLimited', status: 429),
        headers: {
          'retry-after': ['17'],
        },
      ),
    );
    expect(
      (failure as ScanRateLimitedFailure).retryAfter,
      const Duration(seconds: 17),
    );
  });

  test('mapErrorResponse_RateLimitedWithoutRetryAfter_UsesDefault', () {
    final failure = mapErrorResponse(
      _response(429, _problem('Scan.RateLimited', status: 429)),
    );
    expect(
      (failure as ScanRateLimitedFailure).retryAfter,
      ScanLimits.defaultRetryAfter,
    );
  });

  test('mapErrorResponse_LockedOut_UsesRetryAfterHeaderOrDefault', () {
    final withHeader = mapErrorResponse(
      _response(
        423,
        _problem('Auth.LockedOut', status: 423),
        headers: {
          'retry-after': ['900'],
        },
      ),
    );
    expect(
      (withHeader as AccountLockedFailure).retryAfter,
      const Duration(minutes: 15),
    );
    expect(withHeader.info.status, 423);
    final without = mapErrorResponse(
      _response(423, _problem('Auth.LockedOut', status: 423)),
    );
    expect(
      (without as AccountLockedFailure).retryAfter,
      AuthLimits.defaultLockout,
    );
  });

  test('mapErrorResponse_AuthTooManyRequests_UsesRetryAfterOrDefault', () {
    final withHeader = mapErrorResponse(
      _response(
        429,
        _problem('Auth.TooManyRequests', status: 429),
        headers: {
          'retry-after': ['42'],
        },
      ),
    );
    expect(
      (withHeader as AuthRateLimitedFailure).retryAfter,
      const Duration(seconds: 42),
    );
    final without = mapErrorResponse(
      _response(429, _problem('Auth.TooManyRequests', status: 429)),
    );
    expect(
      (without as AuthRateLimitedFailure).retryAfter,
      AuthLimits.defaultRetryAfter,
    );
  });

  test('mapErrorResponse_DailyQuota_RetryAfterOptional', () {
    final withHeader = mapErrorResponse(
      _response(
        429,
        _problem('Scan.DailyQuotaExceeded', status: 429),
        headers: {
          'retry-after': ['3600'],
        },
      ),
    );
    expect(
      (withHeader as ScanQuotaExceededFailure).retryAfter,
      const Duration(hours: 1),
    );
    final without = mapErrorResponse(
      _response(429, _problem('Scan.DailyQuotaExceeded', status: 429)),
    );
    expect((without as ScanQuotaExceededFailure).retryAfter, isNull);
  });

  test('parseRetryAfter_OnlyNonNegativeSeconds', () {
    expect(parseRetryAfter('120'), const Duration(seconds: 120));
    expect(parseRetryAfter(' 5 '), const Duration(seconds: 5));
    expect(parseRetryAfter('0'), Duration.zero);
    expect(parseRetryAfter(null), isNull);
    expect(parseRetryAfter('-1'), isNull);
    expect(parseRetryAfter('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
  });

  group('mapDioException', () {
    final options = RequestOptions(path: '/api/x');

    test('Timeouts_MapToTimeoutFailure', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          mapDioException(DioException(requestOptions: options, type: type)),
          isA<TimeoutFailure>(),
          reason: type.name,
        );
      }
    });

    test('ConnectionProblems_MapToNetworkFailure', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
        DioExceptionType.unknown,
        DioExceptionType.cancel,
        DioExceptionType.badResponse,
      ]) {
        expect(
          mapDioException(DioException(requestOptions: options, type: type)),
          isA<NetworkFailure>(),
          reason: type.name,
        );
      }
    });

    test('BadResponse_MapsTheBody', () {
      final failure = mapDioException(
        DioException.badResponse(
          statusCode: 403,
          requestOptions: options,
          response: _response(403, _problem('Shop.Suspended', status: 403)),
        ),
      );
      expect(failure, isA<ShopSuspendedFailure>());
    });

    test('ErrorAlreadyAFailure_IsPassedThrough', () {
      const failure = TimeoutFailure();
      expect(
        mapDioException(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            error: failure,
          ),
        ),
        same(failure),
      );
    });
  });
}
