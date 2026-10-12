import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/splash_layout.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The wordmark and tagline under the mark, fading up at their brand times
/// (`up` at 1.75 s and 1.9 s). Under "reduce motion" both show their final
/// frame at once (rule 39).
class SplashWordmark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final reduced = StocklyMotion.of(context).reduced;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _rise(
          Text(
            l10n.appName,
            style: context.typo.wordmark.copyWith(color: colors.markInk),
            textAlign: TextAlign.center,
          ),
          SplashTimings.wordmark,
          reduced: reduced,
        ),
        SizedBox(height: context.spacing.xs),
        _rise(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: SplashLayout.taglineMaxWidth,
            ),
            child: Text(
              l10n.splashTagline,
              style: context.typo.tagline.copyWith(color: colors.muted),
              textAlign: TextAlign.center,
            ),
          ),
          SplashTimings.tagline,
          reduced: reduced,
        ),
      ],
    );
  }

  /// Effect delays sit inside the animation's own timeline (no timers).
  static Widget _rise(Widget child, SplashStep step, {required bool reduced}) =>
      child
          .animate(autoPlay: !reduced, value: reduced ? 1 : 0)
          .fadeIn(
            delay: step.start,
            duration: step.duration,
            curve: SplashCurves.textUp,
          )
          .moveY(
            begin: SplashLayout.textRise,
            end: 0,
            delay: step.start,
            duration: step.duration,
            curve: SplashCurves.textUp,
          );
}
