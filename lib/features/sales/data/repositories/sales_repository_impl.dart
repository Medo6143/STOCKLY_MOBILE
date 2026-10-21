import 'dart:convert';

import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/offline/app_database.dart' as db;
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/sales/data/datasources/pending_sales_local_data_source.dart';
import 'package:stockly/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:stockly/features/sales/data/models/sale_dtos.dart';
import 'package:stockly/features/sales/data/models/sale_mapper.dart';
import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/domain/entities/sale_outcome.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

final class SalesRepositoryImpl implements SalesRepository {
  const new({required this._remote, required this._local});

  final SalesRemoteDataSource _remote;
  final PendingSalesLocalDataSource _local;

  @override
  Future<Result<SaleSubmission, Failure>> submit(
    SaleRequest request, {
    required String shopId,
    required String userId,
  }) async {
    final id = request.clientRequestId;
    final stored = await _local.byId(id);
    final body = stored?.requestJson ?? jsonEncode(request.toDto().toJson());
    if (stored == null) {
      await _local.insert(
        clientRequestId: id,
        shopId: shopId,
        userId: userId,
        requestJson: body,
      );
    }
    final result = await safeApiCall(() async {
      final response = await _remote.createSale(body);
      final sale = response.sale.toEntity();
      return response.isRepeat
          ? SaleSubmission.alreadyRecorded(sale)
          : SaleSubmission.created(sale);
    });
    switch (result) {
      // A row before this call means an earlier attempt ended unknown: keep
      // it until an answer proves that attempt was not recorded either.
      case Err(:final failure)
          when failure.leavesSaleOutcomeUnknown ||
              (stored != null && !failure.provesSaleNotRecorded):
        final row = await _local.byId(id);
        if (row != null) {
          await _local.recordUnknownOutcome(
            row,
            errorCode: failure is ApiFailure ? failure.code.wire : null,
          );
        }
      case Ok() || Err():
        await _local.delete(id);
    }
    return result;
  }

  @override
  Future<PendingSale?> pendingSale(String shopId) async =>
      _toEntity(await _local.oldestOfShop(shopId));

  @override
  Stream<PendingSale?> watchPendingSale(String shopId) =>
      _local.watchOldestOfShop(shopId).map(_toEntity);

  @override
  Future<void> discardPending(String clientRequestId) =>
      _local.delete(clientRequestId);

  @override
  Future<Result<Paged<SaleListItem>, Failure>> getSales({
    required DateTime? from,
    required int page,
    required int pageSize,
  }) => safeApiCall(() async {
    final response = await _remote.getSales(
      from: from,
      page: page,
      pageSize: pageSize,
    );
    return response.toPaged((item) => item.toEntity());
  });

  @override
  Future<Result<Sale, Failure>> getSale(String saleId) =>
      safeApiCall(() async => (await _remote.getSale(saleId)).toEntity());

  /// The stored row with its request parsed back; the body was written by
  /// this app, from the same DTO.
  static PendingSale? _toEntity(db.PendingSale? row) {
    if (row == null) {
      return null;
    }
    final request = CreateSaleRequestDto.fromJson(
      requireJsonObject(jsonDecode(row.requestJson)),
    );
    return row.toEntity(request.toEntity());
  }
}
