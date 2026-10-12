import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/app_version.dart';
import 'package:stockly/core/fake_backend/fake_backend_provider.dart';
import 'package:stockly/core/fake_backend/panel/fake_backend_panel.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/preferences/theme_mode_notifier.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_notifier.dart';
import 'package:stockly/features/settings/presentation/widgets/settings_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Language, theme, shop and account info, sign out and the app version
/// (design §11). States: loading = the sign-out spinner (and the moment the
/// session is gone); empty = n/a; error = none blocks sign out, it always
/// clears the device; data = the settings list. In fake mode a long press
/// on the version opens the fake backend panel (design §12.1).
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).navSettings)),
      body: AsyncStateView<Session>(
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
    final fakeMode = ref.watch(fakeBackendProvider) != null;
    final gutter = EdgeInsetsDirectional.symmetric(horizontal: spacing.md);
    Widget header(String text) => Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.md,
        spacing.lg,
        spacing.md,
        spacing.xs,
      ),
      child: Text(
        text,
        style: textTheme.labelLarge?.copyWith(color: colors.muted),
      ),
    );
    Widget info(String label, String value, {bool ltr = false}) => ListTile(
      title: Text(label),
      subtitle: Text(
        value,
        textDirection: ltr ? TextDirection.ltr : null,
        textAlign: TextAlign.start,
      ),
    );
    return ListView(
      padding: EdgeInsetsDirectional.only(bottom: spacing.xl),
      children: [
        header(l10n.settingsLanguage),
        Padding(
          padding: gutter,
          child: SegmentedButton<LocalePreference>(
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
        ),
        header(l10n.settingsTheme),
        Padding(
          padding: gutter,
          child: SegmentedButton<ThemeMode>(
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
        ),
        header(l10n.settingsShop),
        info(l10n.settingsShopName, session.shop.name),
        info(
          l10n.settingsShopType,
          settingsShopTypeLabel(l10n, session.shop.shopType),
        ),
        info(l10n.settingsRole, shopRoleLabel(l10n, session.shop.role)),
        header(l10n.settingsAccount),
        info(l10n.settingsUserName, session.user.fullName),
        info(l10n.settingsUserEmail, session.user.email, ltr: true),
        SizedBox(height: spacing.md),
        Padding(
          padding: gutter,
          child: OutlinedButton.icon(
            onPressed: signingOut
                ? null
                : ref.read(signOutProvider.notifier).signOut,
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
        SizedBox(height: spacing.lg),
        Center(
          child: GestureDetector(
            onLongPress: fakeMode ? () => _openFakePanel(context, ref) : null,
            child: Padding(
              padding: EdgeInsetsDirectional.all(spacing.xs),
              child: Text(
                l10n.settingsVersion(AppVersion.display),
                style: textTheme.bodySmall?.copyWith(color: colors.muted),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFakePanel(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => FakeBackendPanel(
          shopId: session.shop.id,
          onShopSuspended: ref.read(authProvider.notifier).restore,
        ),
      );
}
