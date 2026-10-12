import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/core/time/countdown.dart';
import 'package:stockly/features/auth/domain/entities/auth_input_rules.dart';
import 'package:stockly/features/auth/presentation/providers/auth_form_failures.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';
import 'package:stockly/features/auth/presentation/providers/login_form_state.dart';

/// Signs in (A2). A lockout (`423`) shows the minutes left and keeps the
/// form usable; a rate limit (`429`) blocks submit until `Retry-After`
/// passes (contract v1.4).
final class LoginFormNotifier extends Notifier<LoginFormState> {
  late Countdown _countdown;

  @override
  LoginFormState build() {
    _countdown = Countdown(ref.watch(clockProvider));
    ref.onDispose(_countdown.cancel);
    return const LoginFormState();
  }

  Future<void> submit({required String email, required String password}) async {
    if (!state.canSubmit) {
      return;
    }
    _countdown.cancel();
    final issues = AuthInputRules.login(email: email, password: password);
    if (issues.isNotEmpty) {
      state = LoginFormState(issues: issues);
      return;
    }
    state = const LoginFormState(isSubmitting: true);
    final result = await ref
        .read(loginUseCaseProvider)
        .call(email: email, password: password);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        await ref.read(authProvider.notifier).signIn(value);
        if (ref.mounted) {
          state = const LoginFormState();
        }
      case Err(:final failure):
        _fail(failure);
    }
  }

  void _fail(Failure failure) {
    final parts = AuthFormFailures.of(failure);
    state = LoginFormState(
      serverErrors: parts.serverErrors,
      fieldFailures: parts.fieldFailures,
      failure: parts.banner,
    );
    switch (failure) {
      case AccountLockedFailure(:final retryAfter):
        _countdown.start(retryAfter, (remaining) {
          state = remaining > Duration.zero
              ? state.copyWith(lockoutRemaining: remaining)
              : state.copyWith(lockoutRemaining: null, failure: null);
        });
      case AuthRateLimitedFailure(:final retryAfter):
        _countdown.start(retryAfter, (remaining) {
          state = remaining > Duration.zero
              ? state.copyWith(retryAfterRemaining: remaining)
              : state.copyWith(retryAfterRemaining: null, failure: null);
        });
      default:
        break;
    }
  }
}

final NotifierProvider<LoginFormNotifier, LoginFormState> loginFormProvider =
    NotifierProvider.autoDispose<LoginFormNotifier, LoginFormState>(
      LoginFormNotifier.new,
    );
