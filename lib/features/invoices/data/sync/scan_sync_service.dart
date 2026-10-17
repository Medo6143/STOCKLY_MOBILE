import 'package:drift/drift.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/offline/app_database.dart' as db;
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/offline/backoff_policy.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart' as db;
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/datasources/pending_scans_local_data_source.dart';
import 'package:stockly/features/invoices/data/models/invoice_mapper.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';

/// Uploads queued scans (design §6.4): one row at a time under the
/// cross-isolate `scanSync` lease, always with the row's stored
/// `clientRequestId`, and only rows of the signed-in shop (§6.7). Every
/// response moves the row along the state machine of §6.3.
final class ScanSyncService {
  new({
    required this._local,
    required this._remote,
    required this._leases,
    required this._tokens,
    required this._background,
    required this._backoff,
    required this._clock,
  });

  final PendingScansLocalDataSource _local;
  final InvoicesRemoteDataSource _remote;
  final LeaseService _leases;
  final TokenStorage _tokens;
  final BackgroundSyncRegistrar _background;
  final BackoffPolicy _backoff;
  final Clock _clock;

  /// Uploads the due rows of the signed-in shop, oldest first, until one
  /// says to stop (rate limit, quota, session). [force] ignores
  /// `nextAttemptAt`. Returns the earliest `nextAttemptAt` left.
  Future<DateTime?> runOnce({required bool force}) async {
    final shopId = (await _tokens.read())?.shop.id;
    if (shopId == null) {
      return null;
    }
    await _withLease(
      () => _local.resetStuckUploads(
        cutoff: _clock.now().subtract(SyncTimings.leaseTtl),
        now: _clock.now(),
      ),
    );
    final attempted = <String>{};
    while (true) {
      final due = await _local.dueScans(
        shopId,
        now: _clock.now(),
        force: force,
      );
      final next = due
          .where((s) => !attempted.contains(s.clientRequestId))
          .firstOrNull;
      if (next == null) {
        break;
      }
      attempted.add(next.clientRequestId);
      final outcome = await _withLease(() => _attempt(next.clientRequestId));
      if (outcome == null || outcome.stopsTheRun) {
        break;
      }
    }
    return await _local.earliestNextAttempt(shopId);
  }

  /// One attempt of [clientRequestId] now, whatever its `nextAttemptAt`.
  Future<ScanUploadOutcome> uploadNow(String clientRequestId) async {
    final shopId = (await _tokens.read())?.shop.id;
    final row = await _local.scan(clientRequestId);
    if (shopId == null || row == null || row.shopId != shopId) {
      return const ScanUploadOutcome.notQueued();
    }
    final attempt = await _withLease(() => _attempt(clientRequestId));
    return attempt?.outcome ?? const ScanUploadOutcome.notQueued();
  }

  Future<T?> _withLease<T>(Future<T> Function() action) => _leases.withLease(
    LeaseNames.scanSync,
    ttl: SyncTimings.leaseTtl,
    wait: SyncTimings.leaseWait,
    action: action,
  );

  Future<_Attempt> _attempt(String clientRequestId) async {
    final row = await _local.scan(clientRequestId);
    if (row == null ||
        !(row.status == db.PendingScanStatus.queued ||
            row.status == db.PendingScanStatus.waitingRetry ||
            row.status == db.PendingScanStatus.rateLimited ||
            row.status == db.PendingScanStatus.quotaExceeded)) {
      return const _Attempt(ScanUploadOutcome.notQueued());
    }
    final now = _clock.now();
    if (!_local.photoExists(row.imagePath)) {
      return await _finish(
        row,
        db.PendingScanStatus.failedPermanent,
        errorCode: LocalFailureReason.storage.name,
      );
    }
    await _local.update(
      clientRequestId,
      db.PendingScansCompanion(
        status: const Value(db.PendingScanStatus.uploading),
        attemptCount: Value(row.attemptCount + 1),
        updatedAt: Value(now),
      ),
    );
    final result = await safeApiCall(
      () => _remote.scan(
        clientRequestId: row.clientRequestId,
        imagePath: row.imagePath,
      ),
    );
    return switch (result) {
      Ok(:final value) => await _uploaded(row, value),
      Err(:final failure) => await _failed(
        row,
        failure,
        attempt: row.attemptCount + 1,
      ),
    };
  }

  Future<_Attempt> _uploaded(
    db.PendingScan row,
    ScanUploadResponse response,
  ) async {
    await _local.delete(row);
    final invoiceId = response.invoice.id;
    return _Attempt(
      response.isRepeat
          ? ScanUploadOutcome.alreadyUploaded(invoiceId)
          : ScanUploadOutcome.created(invoiceId),
    );
  }

  Future<_Attempt> _failed(
    db.PendingScan row,
    Failure failure, {
    required int attempt,
  }) async {
    final now = _clock.now();
    switch (failure) {
      case PayloadTooLargeFailure(:final code) ||
          InvalidInputFailure(:final code) ||
          ValidationFailure(:final code):
        return await _finish(
          row,
          db.PendingScanStatus.failedPermanent,
          errorCode: code.wire,
        );
      case ScanRateLimitedFailure(:final code, :final retryAfter):
        return await _finish(
          row,
          db.PendingScanStatus.rateLimited,
          errorCode: code.wire,
          nextAttemptAt: now.add(retryAfter),
          stop: true,
        );
      case ScanQuotaExceededFailure(:final code, :final retryAfter):
        await _local.markQuotaExceeded(
          row.shopId,
          now: now,
          nextAttemptAt: now.add(retryAfter ?? SyncTimings.quotaRecheck),
          errorCode: code.wire,
        );
        await _requestBackground();
        return const _Attempt(
          ScanUploadOutcome.waiting(PendingScanStatus.quotaExceeded),
          stopsTheRun: true,
        );
      case SessionEndedFailure(:final code) ||
          ShopSuspendedFailure(:final code):
        return await _finish(
          row,
          db.PendingScanStatus.queued,
          errorCode: code.wire,
          stop: true,
        );
      case ApiFailure(:final code):
        return await _retryLater(row, code.wire, attempt);
      case UnknownApiFailure(:final rawCode):
        return await _retryLater(row, rawCode, attempt);
      case NetworkFailure() ||
          TimeoutFailure() ||
          MalformedResponseFailure() ||
          LocalFailure():
        return await _retryLater(row, null, attempt);
    }
  }

  Future<_Attempt> _retryLater(
    db.PendingScan row,
    String? errorCode,
    int attempt,
  ) => _finish(
    row,
    db.PendingScanStatus.waitingRetry,
    errorCode: errorCode,
    nextAttemptAt: _clock.now().add(_backoff.delayFor(attempt)),
  );

  Future<_Attempt> _finish(
    db.PendingScan row,
    db.PendingScanStatus status, {
    required String? errorCode,
    DateTime? nextAttemptAt,
    bool stop = false,
  }) async {
    await _local.update(
      row.clientRequestId,
      db.PendingScansCompanion(
        status: Value(status),
        nextAttemptAt: Value(nextAttemptAt),
        lastErrorCode: Value(errorCode),
        updatedAt: Value(_clock.now()),
      ),
    );
    if (status != db.PendingScanStatus.failedPermanent) {
      await _requestBackground();
    }
    return _Attempt(
      ScanUploadOutcome.waiting(status.toEntity()),
      stopsTheRun: stop,
    );
  }

  /// A failed attempt also schedules the background upload (design §6.5).
  Future<void> _requestBackground() async {
    try {
      await _background.requestUpload();
    } on Exception {
      // Background work is best-effort; the foreground triggers and the
      // periodic task still upload.
    }
  }
}

/// The outcome of one attempt, and whether the run must stop after it.
final class _Attempt {
  const new(this.outcome, {this.stopsTheRun = false});

  final ScanUploadOutcome outcome;
  final bool stopsTheRun;
}
