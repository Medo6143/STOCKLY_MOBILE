import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_notifier.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';

/// The shop's payments (B5), newest first, page by page.
final class PaymentHistoryNotifier extends PagedNotifier<Payment> {
  @override
  Future<Result<Paged<Payment>, Failure>> fetchPage(int page) =>
      ref.read(getPaymentsUseCaseProvider).call(page: page);
}

final AsyncNotifierProvider<PaymentHistoryNotifier, PagedState<Payment>>
paymentHistoryProvider =
    AsyncNotifierProvider.autoDispose<
      PaymentHistoryNotifier,
      PagedState<Payment>
    >(PaymentHistoryNotifier.new);
