import 'package:stockly/core/offline/app_database.dart' as db;
import 'package:stockly/features/sales/data/models/sale_dtos.dart';
import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';

/// Contract strings of the sale warnings (§7, §9).
abstract final class SaleWire {
  static const Map<String, SaleWarningCode> warningCodes = {
    'Stock.NegativeBalance': SaleWarningCode.negativeBalance,
  };
}

extension SaleItemDtoMapper on SaleItemDto {
  SaleItem toEntity() => SaleItem(
    id: id,
    productId: productId,
    productName: productName,
    productUnitId: productUnitId,
    unitName: unitName,
    quantity: quantity,
    listUnitPrice: listUnitPrice,
    unitPrice: unitPrice,
    priceOverridden: priceOverridden,
    lineTotal: lineTotal,
    balanceAfter: balanceAfter,
  );
}

extension SaleWarningDtoMapper on SaleWarningDto {
  /// Throws [FormatException] for a code the contract does not list.
  SaleWarning toEntity() => SaleWarning(
    code:
        SaleWire.warningCodes[code] ??
        (throw FormatException('Unknown sale warning', code)),
    productId: productId,
  );
}

extension SaleDtoMapper on SaleDto {
  Sale toEntity() => Sale(
    id: id,
    clientRequestId: clientRequestId,
    totalAmount: totalAmount,
    note: note,
    priceOverridden: priceOverridden,
    items: [for (final item in items) item.toEntity()],
    createdAt: createdAt,
    createdByUserId: createdByUserId,
    warnings: [for (final warning in warnings) warning.toEntity()],
  );
}

extension SaleListItemDtoMapper on SaleListItemDto {
  SaleListItem toEntity() => SaleListItem(
    id: id,
    totalAmount: totalAmount,
    itemCount: itemCount,
    createdAt: createdAt,
  );
}

extension SaleRequestMapper on SaleRequest {
  CreateSaleRequestDto toDto() => CreateSaleRequestDto(
    clientRequestId: clientRequestId,
    note: note,
    items: [
      for (final item in items)
        CreateSaleItemRequestDto(
          productId: item.productId,
          productUnitId: item.productUnitId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
        ),
    ],
  );
}

extension CreateSaleRequestDtoMapper on CreateSaleRequestDto {
  SaleRequest toEntity() => SaleRequest(
    clientRequestId: clientRequestId,
    note: note,
    items: [
      for (final item in items)
        SaleRequestItem(
          productId: item.productId,
          productUnitId: item.productUnitId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
        ),
    ],
  );
}

/// A stored pending sale; `request` is its parsed request body.
extension PendingSaleRowMapper on db.PendingSale {
  PendingSale toEntity(SaleRequest request) => PendingSale(
    request: request,
    attemptCount: attemptCount,
    createdAt: createdAt,
  );
}
