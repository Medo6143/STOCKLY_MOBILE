import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/sales/data/datasources/pending_sales_local_data_source.dart';
import 'package:stockly/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:stockly/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';
import 'package:stockly/features/sales/domain/usecases/discard_pending_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/get_pending_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/get_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/get_sales_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/submit_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/watch_pending_sale_use_case.dart';

// Composition root of the sales feature: the only presentation file that
// imports the data layer (design §1.1).

final salesRemoteDataSourceProvider = Provider<SalesRemoteDataSource>(
  (ref) => SalesRemoteDataSource(ref.watch(dioProvider)),
);

final pendingSalesLocalDataSourceProvider =
    Provider<PendingSalesLocalDataSource>(
      (ref) => PendingSalesLocalDataSource(
        ref.watch(appDatabaseProvider).pendingSalesDao,
        ref.watch(clockProvider),
      ),
    );

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepositoryImpl(
    remote: ref.watch(salesRemoteDataSourceProvider),
    local: ref.watch(pendingSalesLocalDataSourceProvider),
  ),
);

final submitSaleUseCaseProvider = Provider<SubmitSaleUseCase>(
  (ref) => SubmitSaleUseCase(ref.watch(salesRepositoryProvider)),
);

final getSalesUseCaseProvider = Provider<GetSalesUseCase>(
  (ref) => GetSalesUseCase(ref.watch(salesRepositoryProvider)),
);

final getSaleUseCaseProvider = Provider<GetSaleUseCase>(
  (ref) => GetSaleUseCase(ref.watch(salesRepositoryProvider)),
);

final getPendingSaleUseCaseProvider = Provider<GetPendingSaleUseCase>(
  (ref) => GetPendingSaleUseCase(ref.watch(salesRepositoryProvider)),
);

final watchPendingSaleUseCaseProvider = Provider<WatchPendingSaleUseCase>(
  (ref) => WatchPendingSaleUseCase(ref.watch(salesRepositoryProvider)),
);

final discardPendingSaleUseCaseProvider = Provider<DiscardPendingSaleUseCase>(
  (ref) => DiscardPendingSaleUseCase(ref.watch(salesRepositoryProvider)),
);
