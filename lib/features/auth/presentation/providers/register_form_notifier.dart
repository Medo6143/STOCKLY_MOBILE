import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/core/time/countdown.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/auth_input_rules.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/presentation/providers/auth_form_failures.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';
import 'package:stockly/features/auth/presentation/providers/register_form_state.dart';

/// What the register form holds when it is submitted.
final class RegisterDraft {
  const new({
    required this.fullName,
    required this.email,
    required this.password,
    required this.shopName,
    this.phone = '',
    this.shopPhone = '',
    this.shopGovernorate = '',
    this.shopAddress = '',
  });

  final String fullName;
  final String email;
  final String password;
  final String phone;
  final String shopName;
  final String shopPhone;
  final String shopGovernorate;
  final String shopAddress;
}

/// Creates the user, the shop and the Owner membership (A1). Sends the
/// current app language as `preferredLanguage` (design §8.2).
final class RegisterFormNotifier extends Notifier<RegisterFormState> {
  late Countdown _countdown;

  @override
  RegisterFormState build() {
    _countdown = Countdown(ref.watch(clockProvider));
    ref.onDispose(_countdown.cancel);
    return const RegisterFormState();
  }

  void selectShopType(ShopType type) {
    final issues = {...state.issues}..remove(AuthField.shopType);
    final failures = {...state.fieldFailures}..remove(AuthField.shopType);
    final serverErrors = {...state.serverErrors}..remove(AuthField.shopType);
    state = state.copyWith(
      shopType: type,
      issues: issues,
      fieldFailures: failures,
      serverErrors: serverErrors,
    );
  }

  Future<void> submit(RegisterDraft draft) async {
    if (!state.canSubmit) {
      return;
    }
    _countdown.cancel();
    final shopType = state.shopType;
    final issues = AuthInputRules.register(
      fullName: draft.fullName,
      email: draft.email,
      password: draft.password,
      phone: draft.phone,
      shopName: draft.shopName,
      shopType: shopType,
      shopPhone: draft.shopPhone,
      shopGovernorate: draft.shopGovernorate,
      shopAddress: draft.shopAddress,
    );
    if (issues.isNotEmpty || shopType == null) {
      state = RegisterFormState(shopType: shopType, issues: issues);
      return;
    }
    state = RegisterFormState(shopType: shopType, isSubmitting: true);
    final result = await ref
        .read(registerUseCaseProvider)
        .call(
          RegisterInput(
            fullName: draft.fullName.trim(),
            email: draft.email.trim(),
            password: draft.password,
            preferredLanguage: _language,
            shopName: draft.shopName.trim(),
            shopType: shopType,
            phone: _optional(draft.phone),
            shopPhone: _optional(draft.shopPhone),
            shopGovernorate: _optional(draft.shopGovernorate),
            shopAddress: _optional(draft.shopAddress),
          ),
        );
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        await ref.read(authProvider.notifier).signIn(value);
        if (ref.mounted) {
          state = RegisterFormState(shopType: shopType);
        }
      case Err(:final failure):
        _fail(failure, shopType);
    }
  }

  AppLanguage get _language =>
      AppLanguage.values.asNameMap()[ref.read(localeProvider).languageCode] ??
      AppLanguage.ar;

  static String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _fail(Failure failure, ShopType shopType) {
    final parts = AuthFormFailures.of(failure);
    state = RegisterFormState(
      shopType: shopType,
      serverErrors: parts.serverErrors,
      fieldFailures: parts.fieldFailures,
      failure: parts.banner,
    );
    if (failure case AuthRateLimitedFailure(:final retryAfter)) {
      _countdown.start(retryAfter, (remaining) {
        state = remaining > Duration.zero
            ? state.copyWith(retryAfterRemaining: remaining)
            : state.copyWith(retryAfterRemaining: null, failure: null);
      });
    }
  }
}

final NotifierProvider<RegisterFormNotifier, RegisterFormState>
registerFormProvider =
    NotifierProvider.autoDispose<RegisterFormNotifier, RegisterFormState>(
      RegisterFormNotifier.new,
    );
