import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/action_tile.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/hero_header.dart';
import 'package:stockly/core/widgets/hero_scroll_frame.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/overlap_up.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/settings/presentation/providers/profile_providers.dart';
import 'package:stockly/features/settings/presentation/widgets/profile_avatar.dart';
import 'package:stockly/features/settings/presentation/widgets/settings_labels.dart';
import 'package:stockly/features/settings/presentation/widgets/sign_out_flow.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The profile tab (design-refresh brief), from the session in memory, no
/// request. States: loading = a skeleton header while the session is not
/// known yet; empty = not applicable (a signed-in user always has a
/// session; without one the router leaves the tab, and the moment before
/// shows the loading skeleton); error = the session could not be read,
/// with retry (restores it); data = the header (avatar, name, email,
/// phone, role), the shop card and the actions: settings, the privacy
/// policy and sign out (with the pending-scans warning, design §6.7).
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: HeroScrollFrame(
      child: AsyncStateView<Session>(
        value: ref.watch(profileSessionProvider),
        loading: const SafeArea(
          child: LoadingState(shape: LoadingShape.profile),
        ),
        onRetry: () => ref.read(authProvider.notifier).restore(),
        data: (context, session) => _ProfileBody(session: session),
      ),
    ),
  );
}

class _ProfileBody extends ConsumerWidget {
  const new({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final signingOut = ref.watch(signOutProvider).inProgress;
    final pending = ref.watch(pendingScanCountProvider).value ?? 0;
    final overlap = spacing.xxl;
    final actions = [
      ActionTile(
        icon: Icons.settings_outlined,
        title: l10n.navSettings,
        subtitle: l10n.profileSettingsSubtitle,
        onTap: () => context.goNamed(RouteNames.settings),
      ),
      ActionTile(
        icon: Icons.privacy_tip_outlined,
        title: l10n.privacyPolicyTitle,
        subtitle: l10n.privacyPolicySubtitle,
        onTap: () => context.pushNamed(RouteNames.privacyPolicy),
      ),
      ActionTile(
        icon: Icons.logout_rounded,
        title: l10n.authSignOut,
        subtitle: l10n.profileSignOutSubtitle,
        tone: PillTone.danger,
        onTap: signingOut
            ? null
            : () => signOutWithWarning(context, ref, pending: pending),
        trailing: signingOut
            ? SizedBox.square(
                dimension: spacing.md,
                child: CircularProgressIndicator(
                  strokeWidth: spacing.xxs / 2,
                  semanticsLabel: l10n.commonLoading,
                ),
              )
            : null,
      ),
    ];
    return EntranceScope(
      child: ListView(
        padding: EdgeInsetsDirectional.only(bottom: spacing.xl),
        children: [
          HeroHeader(
            overlap: overlap,
            child: _ProfileHeader(session: session),
          ),
          OverlapUp(
            overlap: overlap,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
              child: Entrance(child: _ShopCard(session: session)),
            ),
          ),
          for (final (index, action) in actions.indexed)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                spacing.md,
                spacing.sm,
                spacing.md,
                0,
              ),
              child: Entrance(index: index + 1, child: action),
            ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const new({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final user = session.user;
    final phone = user.phone;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.onHeroMuted);
    Widget contact(IconData icon, String text, String label) => Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: spacing.md, color: colors.onHeroMuted),
          SizedBox(width: spacing.xxs),
          Flexible(child: Text(text, style: muted)),
        ],
      ),
    );
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.navProfile,
            style: textTheme.titleLarge?.copyWith(color: colors.onHero),
          ),
        ),
        SizedBox(height: spacing.md),
        ProfileAvatar(name: user.fullName),
        SizedBox(height: spacing.sm),
        Text(
          user.fullName,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(color: colors.onHero),
        ),
        SizedBox(height: spacing.xxs),
        contact(
          Icons.alternate_email_rounded,
          ltrIsolate(user.email),
          l10n.settingsUserEmail,
        ),
        if (phone != null) ...[
          SizedBox(height: spacing.xxs),
          contact(Icons.phone_rounded, ltrIsolate(phone), l10n.profilePhone),
        ],
        SizedBox(height: spacing.sm),
        StatusPill(
          label: shopRoleLabel(l10n, session.shop.role),
          tone: PillTone.mint,
          icon: switch (session.shop.role) {
            ShopRole.owner => Icons.workspace_premium_rounded,
            ShopRole.staff => Icons.badge_outlined,
          },
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  const new({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      level: 2,
      radius: context.radii.xxl,
      child: Row(
        children: [
          LeadingBadge(icon: Icons.storefront_rounded, size: spacing.huge),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsShop,
                  style: textTheme.labelLarge?.copyWith(color: colors.muted),
                ),
                Text(session.shop.name, style: textTheme.titleLarge),
                Text(
                  settingsShopTypeLabel(l10n, session.shop.shopType),
                  style: textTheme.bodyMedium?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
