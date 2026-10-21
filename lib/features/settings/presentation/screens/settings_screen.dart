import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/app_version.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/preferences/theme_mode_notifier.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/press_scale.dart';
import 'package:stockly/core/widgets/section_card.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/settings/presentation/widgets/settings_labels.dart';
import 'package:stockly/features/settings/presentation/widgets/sign_out_flow.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Language, theme, shop and account info, sign out and the app version
/// (design §11), opened from the profile (`/profile/settings`). States:
/// loading = the sign-out spinner (and the moment the session is gone);
/// empty = n/a; error = none blocks sign out, it always clears the device;
/// data = the settings in section cards. Signing out with scans still in
/// the queue asks first (design §6.7).
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).navSettings)),
      body: AsyncStateView<Session>(
        loading: const LoadingState(shape: LoadingShape.form),
        value: session == null
            ? const AsyncLoading<Session>()
            : AsyncData(session),
        data: (context, session) => _SettingsList(session: session),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const new({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final signingOut = ref.watch(signOutProvider).inProgress;
    final pending = ref.watch(pendingScanCountProvider).value ?? 0;
    Widget info(String label, String value, {bool ltr = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ),
        SizedBox(width: spacing.sm),
        Flexible(
          child: Text(
            value,
            textDirection: ltr ? TextDirection.ltr : null,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
    final sections = <Widget>[
      SectionCard(
        title: l10n.settingsLanguage,
        icon: Icons.translate_rounded,
        children: [
          SegmentedButton<LocalePreference>(
            showSelectedIcon: false,
            segments: [
              for (final value in LocalePreference.values)
                ButtonSegment(
                  value: value,
                  label: Text(localePreferenceLabel(l10n, value)),
                ),
            ],
            selected: {ref.watch(localePreferenceProvider)},
            onSelectionChanged: (selected) => ref
                .read(localeProvider.notifier)
                .setPreference(selected.single),
          ),
        ],
      ),
      SectionCard(
        title: l10n.settingsTheme,
        icon: Icons.contrast_rounded,
        children: [
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              for (final value in ThemeMode.values)
                ButtonSegment(
                  value: value,
                  label: Text(themeModeLabel(l10n, value)),
                ),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (selected) => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(selected.single),
          ),
        ],
      ),
      SectionCard(
        title: l10n.settingsShop,
        icon: Icons.storefront_rounded,
        children: [
          info(l10n.settingsShopName, session.shop.name),
          info(
            l10n.settingsShopType,
            settingsShopTypeLabel(l10n, session.shop.shopType),
          ),
          info(l10n.settingsRole, shopRoleLabel(l10n, session.shop.role)),
        ],
      ),
      SectionCard(
        title: l10n.settingsAccount,
        icon: Icons.person_outline_rounded,
        children: [
          info(l10n.settingsUserName, session.user.fullName),
          info(l10n.settingsUserEmail, session.user.email, ltr: true),
        ],
      ),
      PressScale(
        enabled: !signingOut,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: colors.danger),
          onPressed: signingOut
              ? null
              : () => signOutWithWarning(context, ref, pending: pending),
          icon: signingOut
              ? SizedBox.square(
                  dimension: spacing.md,
                  child: CircularProgressIndicator(
                    strokeWidth: spacing.xxs / 2,
                    semanticsLabel: l10n.commonLoading,
                  ),
                )
              : Icon(Icons.logout_rounded, color: colors.danger),
          label: Text(l10n.authSignOut),
        ),
      ),
      Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.xs),
          child: Text(
            l10n.settingsVersion(AppVersion.display),
            style: textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
        ),
      ),
    ];
    return EntranceScope(
      child: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          spacing.md,
          spacing.xs,
          spacing.md,
          spacing.xl,
        ),
        children: [
          for (final (index, section) in sections.indexed)
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
              child: Entrance(index: index, child: section),
            ),
        ],
      ),
    );
  }
}
