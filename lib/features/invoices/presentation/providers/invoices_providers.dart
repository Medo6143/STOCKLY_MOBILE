import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/media/image_compressor.dart';
import 'package:stockly/core/media/invoice_image_source.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/offline/backoff_policy.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/offline/scan_sync_scheduler.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/datasources/pending_scans_local_data_source.dart';
import 'package:stockly/features/invoices/data/repositories/invoice_photo_source_impl.dart';
import 'package:stockly/features/invoices/data/repositories/invoices_repository_impl.dart';
import 'package:stockly/features/invoices/data/repositories/scan_queue_repository_impl.dart';
import 'package:stockly/features/invoices/data/sync/scan_sync_service.dart';
import 'package:stockly/features/invoices/domain/repositories/invoice_photo_source.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';
import 'package:stockly/features/invoices/domain/usecases/capture_invoice_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/confirm_invoice_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/delete_pending_scan_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/get_invoice_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/get_invoices_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/save_invoice_items_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/sync_pending_scans_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/take_invoice_photo_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/upload_pending_scan_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_invoice_processing_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_pending_scan_count_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_pending_scans_use_case.dart';

// Composition root of the invoices feature: the only presentation file
// that imports the data layer (design §1.1).

final invoicesRemoteDataSourceProvider = Provider<InvoicesRemoteDataSource>(
  (ref) => InvoicesRemoteDataSource(ref.watch(dioProvider)),
);

final pendingScansLocalDataSourceProvider =
    Provider<PendingScansLocalDataSource>(
      (ref) => PendingScansLocalDataSource(
        ref.watch(appDatabaseProvider).pendingScansDao,
        ref.watch(appDirectoriesProvider),
      ),
    );

final scanSyncServiceProvider = Provider<ScanSyncService>(
  (ref) => ScanSyncService(
    local: ref.watch(pendingScansLocalDataSourceProvider),
    remote: ref.watch(invoicesRemoteDataSourceProvider),
    leases: ref.watch(leaseServiceProvider),
    tokens: ref.watch(tokenStorageProvider),
    background: ref.watch(backgroundSyncRegistrarProvider),
    backoff: BackoffPolicy(Random()),
    clock: ref.watch(clockProvider),
  ),
);

final invoicesRepositoryProvider = Provider<InvoicesRepository>(
  (ref) => InvoicesRepositoryImpl(ref.watch(invoicesRemoteDataSourceProvider)),
);

final scanQueueRepositoryProvider = Provider<ScanQueueRepository>(
  (ref) => ScanQueueRepositoryImpl(
    local: ref.watch(pendingScansLocalDataSourceProvider),
    sync: ref.watch(scanSyncServiceProvider),
    compressor: ref.watch(imageCompressorProvider),
    uuid: ref.watch(uuidGeneratorProvider),
    background: ref.watch(backgroundSyncRegistrarProvider),
    clock: ref.watch(clockProvider),
  ),
);

final invoicePhotoSourceProvider = Provider<InvoicePhotoSource>(
  (ref) => InvoicePhotoSourceImpl(ref.watch(invoiceImageSourceProvider)),
);

final getInvoicesUseCaseProvider = Provider<GetInvoicesUseCase>(
  (ref) => GetInvoicesUseCase(ref.watch(invoicesRepositoryProvider)),
);

final getInvoiceUseCaseProvider = Provider<GetInvoiceUseCase>(
  (ref) => GetInvoiceUseCase(ref.watch(invoicesRepositoryProvider)),
);

final saveInvoiceItemsUseCaseProvider = Provider<SaveInvoiceItemsUseCase>(
  (ref) => SaveInvoiceItemsUseCase(ref.watch(invoicesRepositoryProvider)),
);

final confirmInvoiceUseCaseProvider = Provider<ConfirmInvoiceUseCase>(
  (ref) => ConfirmInvoiceUseCase(ref.watch(invoicesRepositoryProvider)),
);

final watchInvoiceProcessingUseCaseProvider =
    Provider<WatchInvoiceProcessingUseCase>(
      (ref) =>
          WatchInvoiceProcessingUseCase(ref.watch(invoicesRepositoryProvider)),
    );

final takeInvoicePhotoUseCaseProvider = Provider<TakeInvoicePhotoUseCase>(
  (ref) => TakeInvoicePhotoUseCase(ref.watch(invoicePhotoSourceProvider)),
);

final captureInvoiceUseCaseProvider = Provider<CaptureInvoiceUseCase>(
  (ref) => CaptureInvoiceUseCase(ref.watch(scanQueueRepositoryProvider)),
);

final uploadPendingScanUseCaseProvider = Provider<UploadPendingScanUseCase>(
  (ref) => UploadPendingScanUseCase(ref.watch(scanQueueRepositoryProvider)),
);

final syncPendingScansUseCaseProvider = Provider<SyncPendingScansUseCase>(
  (ref) => SyncPendingScansUseCase(ref.watch(scanQueueRepositoryProvider)),
);

final deletePendingScanUseCaseProvider = Provider<DeletePendingScanUseCase>(
  (ref) => DeletePendingScanUseCase(ref.watch(scanQueueRepositoryProvider)),
);

final watchPendingScansUseCaseProvider = Provider<WatchPendingScansUseCase>(
  (ref) => WatchPendingScansUseCase(ref.watch(scanQueueRepositoryProvider)),
);

final watchPendingScanCountUseCaseProvider =
    Provider<WatchPendingScanCountUseCase>(
      (ref) =>
          WatchPendingScanCountUseCase(ref.watch(scanQueueRepositoryProvider)),
    );

/// The foreground upload triggers (design §6.5), started by `StocklyApp`.
final scanSyncSchedulerProvider = Provider<ScanSyncScheduler>((ref) {
  final scheduler = ScanSyncScheduler(
    connectivity: ref.watch(connectivityMonitorProvider),
    background: ref.watch(backgroundSyncRegistrarProvider),
    sync: ({required force}) =>
        ref.read(syncPendingScansUseCaseProvider).call(force: force),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
