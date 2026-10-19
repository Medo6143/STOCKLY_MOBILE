import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:stockly/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';
import 'package:stockly/features/billing/domain/usecases/cancel_payment_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/checkout_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_payment_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_payments_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_plans_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_subscription_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/watch_payment_use_case.dart';

// Composition root of the billing feature: the only presentation file that
// imports the data layer (design §1.1).

final billingRemoteDataSourceProvider = Provider<BillingRemoteDataSource>(
  (ref) => BillingRemoteDataSource(ref.watch(dioProvider)),
);

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepositoryImpl(ref.watch(billingRemoteDataSourceProvider)),
);

final getPlansUseCaseProvider = Provider<GetPlansUseCase>(
  (ref) => GetPlansUseCase(ref.watch(billingRepositoryProvider)),
);

final getSubscriptionUseCaseProvider = Provider<GetSubscriptionUseCase>(
  (ref) => GetSubscriptionUseCase(ref.watch(billingRepositoryProvider)),
);

final checkoutUseCaseProvider = Provider<CheckoutUseCase>(
  (ref) => CheckoutUseCase(ref.watch(billingRepositoryProvider)),
);

final getPaymentUseCaseProvider = Provider<GetPaymentUseCase>(
  (ref) => GetPaymentUseCase(ref.watch(billingRepositoryProvider)),
);

final getPaymentsUseCaseProvider = Provider<GetPaymentsUseCase>(
  (ref) => GetPaymentsUseCase(ref.watch(billingRepositoryProvider)),
);

final cancelPaymentUseCaseProvider = Provider<CancelPaymentUseCase>(
  (ref) => CancelPaymentUseCase(ref.watch(billingRepositoryProvider)),
);

final watchPaymentUseCaseProvider = Provider<WatchPaymentUseCase>(
  (ref) => WatchPaymentUseCase(ref.watch(billingRepositoryProvider)),
);
