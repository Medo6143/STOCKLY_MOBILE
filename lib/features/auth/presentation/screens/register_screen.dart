import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/primary_button.dart';
import 'package:stockly/core/widgets/section_card.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/presentation/providers/register_form_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/register_form_state.dart';
import 'package:stockly/features/auth/presentation/widgets/auth_header.dart';
import 'package:stockly/features/auth/presentation/widgets/auth_labels.dart';
import 'package:stockly/features/auth/presentation/widgets/password_field.dart';
import 'package:stockly/features/auth/presentation/widgets/shop_type_picker.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Create the user, the shop and the Owner membership (A1). States (design
/// §11): loading = submit spinner with the fields disabled; empty = the
/// blank form with the shop type picker; error = email taken under the
/// email, shop name or type under their fields, field errors, or a banner
/// (rate limit with seconds left, network); data = the router moves home.
/// A link above the submit button opens the privacy policy.
class RegisterScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late final Map<AuthField, TextEditingController> _text = {
    for (final field in _textFields) field: TextEditingController(),
  };

  static const List<AuthField> _textFields = [
    AuthField.fullName,
    AuthField.email,
    AuthField.password,
    AuthField.phone,
    AuthField.shopName,
    AuthField.shopPhone,
    AuthField.shopGovernorate,
    AuthField.shopAddress,
  ];

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(AuthField field) => _text[field]!.text;

  void _submit() => ref
      .read(registerFormProvider.notifier)
      .submit(
        RegisterDraft(
          fullName: _value(AuthField.fullName),
          email: _value(AuthField.email),
          password: _value(AuthField.password),
          phone: _value(AuthField.phone),
          shopName: _value(AuthField.shopName),
          shopPhone: _value(AuthField.shopPhone),
          shopGovernorate: _value(AuthField.shopGovernorate),
          shopAddress: _value(AuthField.shopAddress),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final form = ref.watch(registerFormProvider);
    final enabled = !form.isSubmitting;
    final banner = form.failure;
    String? errorOf(AuthField field) => authFieldError(
      l10n,
      field,
      issues: form.issues,
      serverErrors: form.serverErrors,
      fieldFailures: form.fieldFailures,
    );
    Widget field(
      AuthField field,
      String label, {
      TextInputType? keyboardType,
      Iterable<String>? autofillHints,
      bool ltr = false,
    }) => TextField(
      controller: _text[field],
      enabled: enabled,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : null,
      autofillHints: autofillHints,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorOf(field),
        errorMaxLines: 3,
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: EdgeInsetsDirectional.all(spacing.xl),
            children: [
              AuthHeader(
                title: l10n.authRegisterTitle,
                subtitle: l10n.authRegisterSubtitle,
              ),
              SizedBox(height: spacing.xl),
              if (banner != null) ...[
                FormBanner(
                  message: authBannerMessage(
                    l10n,
                    banner,
                    retryAfterRemaining: form.retryAfterRemaining,
                  ),
                ),
                SizedBox(height: spacing.md),
              ],
              SectionCard(
                title: l10n.authRegisterAboutYou,
                icon: Icons.person_outline_rounded,
                children: [
                  field(
                    AuthField.fullName,
                    l10n.authFullNameLabel,
                    autofillHints: const [AutofillHints.name],
                  ),
                  field(
                    AuthField.email,
                    l10n.authEmailLabel,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    ltr: true,
                  ),
                  PasswordField(
                    controller: _text[AuthField.password]!,
                    enabled: enabled,
                    errorText: errorOf(AuthField.password),
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                  ),
                  field(
                    AuthField.phone,
                    l10n.authPhoneLabel,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    ltr: true,
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              SectionCard(
                title: l10n.authRegisterYourShop,
                icon: Icons.storefront_outlined,
                children: [
                  field(AuthField.shopName, l10n.authShopNameLabel),
                  ShopTypePicker(
                    selected: form.shopType,
                    enabled: enabled,
                    errorText: errorOf(AuthField.shopType),
                    onSelected: ref
                        .read(registerFormProvider.notifier)
                        .selectShopType,
                  ),
                  field(
                    AuthField.shopPhone,
                    l10n.authShopPhoneLabel,
                    keyboardType: TextInputType.phone,
                    ltr: true,
                  ),
                  field(
                    AuthField.shopGovernorate,
                    l10n.authShopGovernorateLabel,
                  ),
                  field(AuthField.shopAddress, l10n.authShopAddressLabel),
                ],
              ),
              SizedBox(height: spacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.authRegisterPrivacyNote),
                  TextButton(
                    onPressed: () =>
                        context.pushNamed(RouteNames.privacyPolicy),
                    child: Text(l10n.privacyPolicyTitle),
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              PrimaryButton(
                label: l10n.authRegisterSubmit,
                busy: form.isSubmitting,
                onPressed: form.canSubmit ? _submit : null,
              ),
              SizedBox(height: spacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.authRegisterHaveAccount),
                  TextButton(
                    onPressed: enabled
                        ? () => context.go(RoutePaths.login)
                        : null,
                    child: Text(l10n.authRegisterGoToLogin),
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
