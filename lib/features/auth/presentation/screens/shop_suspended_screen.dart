import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_notifier.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The shop is suspended: explain it and allow sign out, the only action
/// left (A4 works for suspended shops). States (design §11): loading = the
/// sign-out spinner (and the moment the session is gone); empty = n/a, the
/// explanation is always shown; error = none blocks sign out, it always
/// clears the device; data = message, shop name and "Sign out".
class ShopSuspendedScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncStateView<Session>(
          value: session == null
              ? const AsyncLoading<Session>()
              : AsyncData(session),
          data: (context, session) => _SuspendedBody(session: session),
        ),
      ),
    );
  }
}

class _SuspendedBody extends ConsumerWidget {
  const new({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final signingOut = ref.watch(signOutProvider).inProgress;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: spacing.huge,
              color: colors.warning,
            ),
            SizedBox(height: spacing.md),
            Text(
              l10n.suspendedTitle,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xs),
            Text(
              session.shop.name,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.md),
            Text(
              l10n.suspendedBody,
              style: textTheme.bodyMedium?.copyWith(color: colors.muted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xl),
            FilledButton.icon(
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
                  : const Icon(Icons.logout_rounded),
              label: Text(l10n.authSignOut),
            ),
          ],
        ),
      ),
    );
  }
}
