import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/primary_button.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/providers/login_form_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/login_form_state.dart';
import 'package:stockly/features/auth/presentation/widgets/auth_header.dart';
import 'package:stockly/features/auth/presentation/widgets/auth_labels.dart';
import 'package:stockly/features/auth/presentation/widgets/password_field.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Sign in (A2). States (design §11): loading = submit spinner with the
/// fields disabled; empty = the blank form; error = wrong credentials under
/// the password, field errors, or a banner (suspended shop, no active shop,
/// lockout with minutes left, rate limit with seconds left, network); data
/// = the router moves to home once signed in.
class LoginScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(loginFormProvider.notifier)
      .submit(email: _email.text, password: _password.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final form = ref.watch(loginFormProvider);
    final banner =
        form.failure ??
        switch (ref.watch(authProvider).value) {
          AuthSignedOut(:final reason) => reason,
          _ => null,
        };
    final enabled = !form.isSubmitting;
    String? errorOf(AuthField field) => authFieldError(
      l10n,
      field,
      issues: form.issues,
      serverErrors: form.serverErrors,
      fieldFailures: form.fieldFailures,
    );
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: EdgeInsetsDirectional.all(spacing.xl),
            children: [
              AuthHeader(
                title: l10n.authLoginTitle,
                subtitle: l10n.authLoginSubtitle,
              ),
              SizedBox(height: spacing.xl),
              if (banner != null) ...[
                FormBanner(
                  message: authBannerMessage(
                    l10n,
                    banner,
                    lockoutRemaining: form.lockoutRemaining,
                    retryAfterRemaining: form.retryAfterRemaining,
                  ),
                ),
                SizedBox(height: spacing.md),
              ],
              SurfaceCard(
                level: 2,
                radius: context.radii.xxl,
                child: Column(
                  children: [
                    TextField(
                      controller: _email,
                      enabled: enabled,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authEmailLabel,
                        errorText: errorOf(AuthField.email),
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    PasswordField(
                      controller: _password,
                      enabled: enabled,
                      errorText: errorOf(AuthField.password),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.xl),
              PrimaryButton(
                label: l10n.authLoginSubmit,
                busy: form.isSubmitting,
                onPressed: form.canSubmit ? _submit : null,
              ),
              SizedBox(height: spacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.authLoginNoAccount),
                  TextButton(
                    onPressed: enabled
                        ? () => context.go(RoutePaths.register)
                        : null,
                    child: Text(l10n.authLoginGoToRegister),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
