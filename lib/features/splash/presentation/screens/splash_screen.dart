import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/auth_redirect.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Start-up screen: restores the saved session, then leaves. The animated
/// brand splash replaces this body in the splash brief; the router moves
/// signed-out and suspended users away by itself.
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(authProvider.notifier).restore(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (next.value is AuthSignedIn) {
        context.go(splashDestination(GoRouterState.of(context).uri));
      }
    });
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appName,
              style: context.typo.wordmark.copyWith(color: context.colors.ink),
            ),
            SizedBox(height: spacing.xs),
            Text(
              l10n.splashTagline,
              style: context.typo.tagline.copyWith(color: context.colors.muted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xl),
            const LoadingState(),
          ],
        ),
      ),
    );
  }
}
