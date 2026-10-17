import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/media/barcode_scanner.dart';
import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

class MockSalesRepository extends Mock implements SalesRepository;

class MockBarcodeScanner extends Mock implements BarcodeScanner;

const String saleId = '0192f0a0-6c1e-7b3a-9d2e-5a1e00000001';
const String saleRequestId = '0192f0a0-6c1e-7b3a-9d2e-5a1e00000099';
const String saleProductId = '0192f0a0-6c1e-7b3a-9d2e-a00000000001';
const String saleBaseUnitId = '0192f0a0-6c1e-7b3a-9d2e-b00000000002';
const String saleUserId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d02';

SaleItem saleItem({
  String name = 'بنادول اكسترا',
  String price = '15.00',
  String listPrice = '15.00',
  String balance = '10.000',
}) => SaleItem(
  id: '0192f0a0-6c1e-7b3a-9d2e-5a1e10000001',
  productId: saleProductId,
  productName: name,
  productUnitId: saleBaseUnitId,
  unitName: 'شريط',
  quantity: Quantity.fromApi('2.000'),
  listUnitPrice: Money.fromApi(listPrice),
  unitPrice: Money.fromApi(price),
  priceOverridden: price != listPrice,
  lineTotal: Money.fromApi('30.00'),
  balanceAfter: Quantity.fromApi(balance),
);

Sale sale({
  List<SaleItem>? items,
  bool negative = false,
  String? note = 'دفع كاش',
}) {
  final lines = items ?? [saleItem()];
  return Sale(
    id: saleId,
    clientRequestId: saleRequestId,
    totalAmount: Money.fromApi('30.00'),
    note: note,
    priceOverridden: lines.any((l) => l.priceOverridden),
    items: lines,
    createdAt: DateTime.utc(2026, 10, 12, 7),
    createdByUserId: saleUserId,
    warnings: [
      if (negative)
        const SaleWarning(
          code: SaleWarningCode.negativeBalance,
          productId: saleProductId,
        ),
    ],
  );
}

SaleListItem saleListItem({String id = saleId}) => SaleListItem(
  id: id,
  totalAmount: Money.fromApi('30.00'),
  itemCount: 2,
  createdAt: DateTime.utc(2026, 10, 12, 7),
);

SaleRequest saleRequest({String id = saleRequestId}) => SaleRequest(
  clientRequestId: id,
  note: null,
  items: [
    SaleRequestItem(
      productId: saleProductId,
      productUnitId: saleBaseUnitId,
      quantity: Quantity.fromApi('1.000'),
      unitPrice: null,
    ),
  ],
);

PendingSale pendingSale({String id = saleRequestId}) => PendingSale(
  request: saleRequest(id: id),
  attemptCount: 1,
  createdAt: DateTime.utc(2026, 10, 12, 7),
);

const NotFoundFailure saleNotFound = NotFoundFailure(
  ApiErrorCode.saleNotFound,
  ApiProblemInfo(status: HttpStatus.notFound),
);

const ServerFailure serverFailure = ServerFailure(
  ApiErrorCode.serverUnexpected,
  ApiProblemInfo(status: HttpStatus.internalServerError),
);

const InvalidInputFailure archivedProduct = InvalidInputFailure(
  ApiErrorCode.saleArchivedProduct,
  ApiProblemInfo(status: HttpStatus.badRequest),
);

/// Registers mocktail fallbacks once per test file.
void registerSaleFallbacks() {
  registerFallbackValue(saleRequest());
  registerFallbackValue(SaleDateRange.today);
}
