import 'dart:io';

import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The localized message of a [Failure] (design §8.4). Chosen by type and
/// `code`, never by the server's `title` or `detail`.
String failureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      SessionEndedFailure() => l10n.errorSessionEnded,
      ApiFailure(:final code) => apiErrorMessage(l10n, code),
      UnknownApiFailure(:final info) =>
        info.status >= HttpStatus.internalServerError
            ? l10n.errorServer
            : l10n.errorUnknown,
      NetworkFailure() => l10n.errorNetwork,
      TimeoutFailure() => l10n.errorTimeout,
      MalformedResponseFailure() => l10n.errorMalformedResponse,
      LocalFailure(:final reason) => localFailureMessage(l10n, reason),
    };

/// One message per [ApiErrorCode]. Exhaustive: a new code is a compile
/// error until it has a message.
String apiErrorMessage(
  AppLocalizations l10n,
  ApiErrorCode code,
) => switch (code) {
  ApiErrorCode.validationFailed => l10n.errorValidationFailed,
  ApiErrorCode.serverUnexpected => l10n.errorServerUnexpected,
  ApiErrorCode.httpNotFound => l10n.errorHttpNotFound,
  ApiErrorCode.httpMethodNotAllowed => l10n.errorHttpMethodNotAllowed,
  ApiErrorCode.httpUnsupportedMediaType => l10n.errorHttpUnsupportedMediaType,
  ApiErrorCode.authUnauthenticated => l10n.errorAuthUnauthenticated,
  ApiErrorCode.authForbidden => l10n.errorAuthForbidden,
  ApiErrorCode.authEmailTaken => l10n.errorAuthEmailTaken,
  ApiErrorCode.authInvalidCredentials => l10n.errorAuthInvalidCredentials,
  ApiErrorCode.authNoActiveShop => l10n.errorAuthNoActiveShop,
  ApiErrorCode.authInvalidRefreshToken => l10n.errorAuthInvalidRefreshToken,
  ApiErrorCode.authRefreshTokenReused => l10n.errorAuthRefreshTokenReused,
  ApiErrorCode.authLockedOut => l10n.errorAuthLockedOut,
  ApiErrorCode.authTooManyRequests => l10n.errorAuthTooManyRequests,
  ApiErrorCode.shopNameRequired => l10n.errorShopNameRequired,
  ApiErrorCode.shopUnknownType => l10n.errorShopUnknownType,
  ApiErrorCode.shopSuspended => l10n.errorShopSuspended,
  ApiErrorCode.productNotFound => l10n.errorProductNotFound,
  ApiErrorCode.productNameRequired => l10n.errorProductNameRequired,
  ApiErrorCode.productArchived => l10n.errorProductArchived,
  ApiErrorCode.productDuplicateBarcode => l10n.errorProductDuplicateBarcode,
  ApiErrorCode.productOpeningStockOwnerOnly =>
    l10n.errorProductOpeningStockOwnerOnly,
  ApiErrorCode.productUnitNotFound => l10n.errorProductUnitNotFound,
  ApiErrorCode.productUnitNameRequired => l10n.errorProductUnitNameRequired,
  ApiErrorCode.productUnitDuplicateName => l10n.errorProductUnitDuplicateName,
  ApiErrorCode.productUnitDuplicateBarcode =>
    l10n.errorProductUnitDuplicateBarcode,
  ApiErrorCode.productUnitBaseUnitCannotBeRemoved =>
    l10n.errorProductUnitBaseUnitCannotBeRemoved,
  ApiErrorCode.productUnitBaseUnitFactorFixed =>
    l10n.errorProductUnitBaseUnitFactorFixed,
  ApiErrorCode.productUnitInUse => l10n.errorProductUnitInUse,
  ApiErrorCode.precisionTooManyDecimals => l10n.errorPrecisionTooManyDecimals,
  ApiErrorCode.precisionNegative => l10n.errorPrecisionNegative,
  ApiErrorCode.precisionNotPositive => l10n.errorPrecisionNotPositive,
  ApiErrorCode.precisionOutOfRange => l10n.errorPrecisionOutOfRange,
  ApiErrorCode.stockZeroChange => l10n.errorStockZeroChange,
  ApiErrorCode.stockNoteRequired => l10n.errorStockNoteRequired,
  ApiErrorCode.invoiceNotFound => l10n.errorInvoiceNotFound,
  ApiErrorCode.invoiceImageRequired => l10n.errorInvoiceImageRequired,
  ApiErrorCode.invoiceUnsupportedImageType =>
    l10n.errorInvoiceUnsupportedImageType,
  ApiErrorCode.invoiceImageTooLarge => l10n.errorInvoiceImageTooLarge,
  ApiErrorCode.invoiceNotEditable => l10n.errorInvoiceNotEditable,
  ApiErrorCode.invoiceNotConfirmable => l10n.errorInvoiceNotConfirmable,
  ApiErrorCode.invoiceLineProductRequired =>
    l10n.errorInvoiceLineProductRequired,
  ApiErrorCode.invoiceUnitNotOfProduct => l10n.errorInvoiceUnitNotOfProduct,
  ApiErrorCode.scanRateLimited => l10n.errorScanRateLimited,
  ApiErrorCode.scanDailyQuotaExceeded => l10n.errorScanDailyQuotaExceeded,
  ApiErrorCode.saleNotFound => l10n.errorSaleNotFound,
  ApiErrorCode.saleArchivedProduct => l10n.errorSaleArchivedProduct,
  ApiErrorCode.saleUnitNotOfProduct => l10n.errorSaleUnitNotOfProduct,
};

String localFailureMessage(AppLocalizations l10n, LocalFailureReason reason) =>
    switch (reason) {
      LocalFailureReason.cameraDenied => l10n.errorLocalCameraDenied,
      LocalFailureReason.imageTooLarge => l10n.errorLocalImageTooLarge,
      LocalFailureReason.queueFull => l10n.errorLocalQueueFull,
      LocalFailureReason.storage => l10n.errorLocalStorage,
    };
