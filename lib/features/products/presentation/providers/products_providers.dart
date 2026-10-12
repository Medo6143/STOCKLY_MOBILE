import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/features/products/data/datasources/products_remote_data_source.dart';
import 'package:stockly/features/products/data/repositories/products_repository_impl.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';
import 'package:stockly/features/products/domain/usecases/add_unit_use_case.dart';
import 'package:stockly/features/products/domain/usecases/adjust_stock_use_case.dart';
import 'package:stockly/features/products/domain/usecases/archive_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/create_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/delete_unit_use_case.dart';
import 'package:stockly/features/products/domain/usecases/get_movements_use_case.dart';
import 'package:stockly/features/products/domain/usecases/get_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/get_products_use_case.dart';
import 'package:stockly/features/products/domain/usecases/lookup_barcode_use_case.dart';
import 'package:stockly/features/products/domain/usecases/record_stock_count_use_case.dart';
import 'package:stockly/features/products/domain/usecases/update_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/update_unit_use_case.dart';

// Composition root of the products feature: the only presentation file
// that imports the data layer (design §1.1).

final productsRemoteDataSourceProvider = Provider<ProductsRemoteDataSource>(
  (ref) => ProductsRemoteDataSource(ref.watch(dioProvider)),
);

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepositoryImpl(ref.watch(productsRemoteDataSourceProvider)),
);

final getProductsUseCaseProvider = Provider<GetProductsUseCase>(
  (ref) => GetProductsUseCase(ref.watch(productsRepositoryProvider)),
);

final getProductUseCaseProvider = Provider<GetProductUseCase>(
  (ref) => GetProductUseCase(ref.watch(productsRepositoryProvider)),
);

final createProductUseCaseProvider = Provider<CreateProductUseCase>(
  (ref) => CreateProductUseCase(ref.watch(productsRepositoryProvider)),
);

final updateProductUseCaseProvider = Provider<UpdateProductUseCase>(
  (ref) => UpdateProductUseCase(ref.watch(productsRepositoryProvider)),
);

final archiveProductUseCaseProvider = Provider<ArchiveProductUseCase>(
  (ref) => ArchiveProductUseCase(ref.watch(productsRepositoryProvider)),
);

final addUnitUseCaseProvider = Provider<AddUnitUseCase>(
  (ref) => AddUnitUseCase(ref.watch(productsRepositoryProvider)),
);

final updateUnitUseCaseProvider = Provider<UpdateUnitUseCase>(
  (ref) => UpdateUnitUseCase(ref.watch(productsRepositoryProvider)),
);

final deleteUnitUseCaseProvider = Provider<DeleteUnitUseCase>(
  (ref) => DeleteUnitUseCase(ref.watch(productsRepositoryProvider)),
);

final adjustStockUseCaseProvider = Provider<AdjustStockUseCase>(
  (ref) => AdjustStockUseCase(ref.watch(productsRepositoryProvider)),
);

final recordStockCountUseCaseProvider = Provider<RecordStockCountUseCase>(
  (ref) => RecordStockCountUseCase(ref.watch(productsRepositoryProvider)),
);

final getMovementsUseCaseProvider = Provider<GetMovementsUseCase>(
  (ref) => GetMovementsUseCase(ref.watch(productsRepositoryProvider)),
);

final lookupBarcodeUseCaseProvider = Provider<LookupBarcodeUseCase>(
  (ref) => LookupBarcodeUseCase(ref.watch(productsRepositoryProvider)),
);
