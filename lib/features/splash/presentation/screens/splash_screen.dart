import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/platform/native_splash.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/splash_layout.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/splash/presentation/providers/splash_notifier.dart';
import 'package:stockly/features/splash/presentation/widgets/animated_stockly_mark.dart';
import 'package:stockly/features/splash/presentation/widgets/splash_loading_dots.dart';
import 'package:stockly/features/splash/presentation/widgets/splash_wordmark.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The animated brand splash (design §10). Takes over from the native
/// splash on its first frame, restores the session and starts the timing
/// gate; the router leaves `/splash` once both allow it (design §3.2).
///
/// States (design §11): loading = the animation with the dots while the
/// session check runs; empty and error never stay here (no session →
/// login, network → offline start, rejected → login, suspended →
/// suspended); data = the router goes to the target.
class SplashScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(nativeSplashProvider).remove();
      ref
          .read(splashProvider.notifier)
          .start(reducedMotion: StocklyMotion.of(context).reduced);
      unawaited(ref.read(authProvider.notifier).restore());
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: AsyncStateView<AuthState>(
      value: ref.watch(authProvider),
      loading: const _SplashBody(checking: true),
      errorBuilder: (context, _) => const _SplashBody(checking: false),
      data: (context, auth) => _SplashBody(checking: auth is AuthUnknown),
    ),
  );
}

class _SplashBody extends StatelessWidget {
  const new({required this.checking});

  /// The session check is still running: show the loading dots.
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: context.spacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedStocklyMark(semanticLabel: l10n.appName),
                SizedBox(height: context.spacing.lg),
                const SplashWordmark(),
              ],
            ),
          ),
        ),
        if (checking)
          const PositionedDirectional(
            start: 0,
            end: 0,
            bottom: SplashLayout.dotsBottom,
            child: Center(child: SplashLoadingDots()),
          ),
      ],
    );
  }
}
