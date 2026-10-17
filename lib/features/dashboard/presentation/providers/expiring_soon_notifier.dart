import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_notifier.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';

/// The lines expiring within [days] days (D2), page by page.
final class ExpiringSoonNotifier extends PagedNotifier<ExpiringItem> {
  new(this.days);

  final int days;

  @override
  Future<Result<Paged<ExpiringItem>, Failure>> fetchPage(int page) =>
      ref.read(getExpiringSoonUseCaseProvider).call(days, page: page);
}

final AsyncNotifierProviderFamily<
  ExpiringSoonNotifier,
  PagedState<ExpiringItem>,
  int
>
expiringSoonProvider = AsyncNotifierProvider.autoDispose
    .family<ExpiringSoonNotifier, PagedState<ExpiringItem>, int>(
      ExpiringSoonNotifier.new,
    );
