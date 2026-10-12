import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/core/theme/stockly_radii.dart';
import 'package:stockly/core/theme/stockly_spacing.dart';
import 'package:stockly/core/theme/stockly_typography.dart';
import 'package:stockly/core/theme/tokens.dart';

void main() {
  group('colors', () {
    test('Light_MatchesTheBrandSheet', () {
      final c = StocklyColors.light;
      expect(c.background, const Color(0xFFF3F7F5));
      expect(c.surface, const Color(0xFFFFFFFF));
      expect(c.ink, const Color(0xFF12233D));
      expect(c.muted, const Color(0xFF5B6B7E));
      expect(c.line, const Color(0xFFDCE5E1));
      expect(c.mint, const Color(0xFF22B57E));
      expect(c.mintSoft, const Color(0xFFD7F3E7));
      expect(c.onMint, const Color(0xFF12233D));
      expect(c.markPaper, const Color(0xFFFFFFFF));
    });

    test('Dark_MatchesTheBrandSheet', () {
      final c = StocklyColors.dark;
      expect(c.background, const Color(0xFF0B1626));
      expect(c.surface, const Color(0xFF13233A));
      expect(c.ink, const Color(0xFFE6EEF5));
      expect(c.muted, const Color(0xFF93A3B5));
      expect(c.line, const Color(0xFF1F3049));
      expect(c.mint, const Color(0xFF3DDC9B));
      expect(c.mintSoft, const Color(0xFF123B32));
      expect(c.onMint, const Color(0xFF0B1626));
      expect(c.markInk, const Color(0xFFE6EEF5));
    });

    test('SoftColors_AreDangerAndWarningOverTheSurface', () {
      expect(
        StocklyColors.light.dangerSoft,
        Color.alphaBlend(
          Tokens.danger.withValues(alpha: Tokens.dangerSoftAlpha),
          Tokens.lightSurface,
        ),
      );
      expect(
        StocklyColors.dark.warningSoft,
        Color.alphaBlend(
          Tokens.warning.withValues(alpha: Tokens.warningSoftAlpha),
          Tokens.darkSurface,
        ),
      );
    });

    test('CopyWithAndLerp', () {
      final light = StocklyColors.light;
      expect(light.copyWith(mint: Tokens.danger).mint, Tokens.danger);
      expect(light.copyWith().ink, light.ink);
      expect(light.lerp(StocklyColors.dark, 1).surface, Tokens.darkSurface);
      expect(light.lerp(null, 0.5), same(light));
    });
  });

  group('AppTheme', () {
    test('ColorScheme_BuiltFromTheTokens', () {
      for (final (theme, colors) in [
        (AppTheme.light(), StocklyColors.light),
        (AppTheme.dark(), StocklyColors.dark),
      ]) {
        final scheme = theme.colorScheme;
        expect(scheme.primary, colors.mint);
        expect(scheme.onPrimary, colors.onMint);
        expect(scheme.primaryContainer, colors.mintSoft);
        expect(scheme.surface, colors.surface);
        expect(scheme.onSurface, colors.ink);
        expect(scheme.onSurfaceVariant, colors.muted);
        expect(scheme.outline, colors.line);
        expect(scheme.error, colors.danger);
        expect(scheme.onError, Tokens.white);
        expect(theme.scaffoldBackgroundColor, colors.background);
        expect(theme.useMaterial3, isTrue);
        expect(theme.extension<StocklyColors>(), same(colors));
        expect(theme.extension<StocklySpacing>()?.md, 16);
        expect(theme.extension<StocklyRadii>()?.md, 14);
        expect(
          theme.extension<StocklyDurations>()?.medium,
          const Duration(milliseconds: 300),
        );
        expect(theme.extension<StocklyTypography>(), isNotNull);
      }
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    test('TextTheme_UsesTheBrandFamiliesAndSizes', () {
      final text = AppTheme.light().textTheme;
      expect(text.displaySmall?.fontFamily, FontFamilies.display);
      expect(text.displaySmall?.fontSize, 34);
      expect(text.titleLarge?.fontSize, 20);
      expect(text.bodyMedium?.fontFamily, FontFamilies.body);
      expect(text.bodyMedium?.fontSize, 15);
      expect(text.bodyMedium?.height, 1.6);
      expect(text.bodyMedium?.color, StocklyColors.light.ink);
      expect(text.labelSmall?.fontSize, 12);
    });
  });

  group('scales', () {
    test('Spacing_FourBased', () {
      const s = StocklySpacing.standard;
      expect(
        [s.xxs, s.xs, s.sm, s.md, s.lg, s.xl, s.xxl, s.xxxl, s.huge],
        [4, 8, 12, 16, 20, 24, 32, 40, 48],
      );
      expect(s.copyWith(md: 18).md, 18);
      expect(s.copyWith().xl, 24);
      expect(s.lerp(null, 0.5), same(s));
    });

    test('Radii_FromTheBrandSheet', () {
      const r = StocklyRadii.standard;
      expect([r.xs, r.sm, r.md, r.lg, r.xl, r.pill], [6, 9, 14, 16, 20, 999]);
      expect(
        r.circular(r.md),
        const BorderRadiusDirectional.all(Radius.circular(14)),
      );
      expect(r.copyWith(pill: 1).pill, 1);
      expect(r.copyWith().lg, 16);
      expect(r.lerp(null, 0.5), same(r));
    });

    test('Durations_FromTheDesign', () {
      const d = StocklyDurations.standard;
      expect(d.fast, const Duration(milliseconds: 150));
      expect(d.slow, const Duration(milliseconds: 500));
      expect(d.searchDebounce, const Duration(milliseconds: 300));
      expect(d.snackbar, const Duration(seconds: 4));
      expect(d.copyWith(fast: Duration.zero).fast, Duration.zero);
      expect(d.copyWith().slow, d.slow);
      expect(d.lerp(null, 0.5), same(d));
    });

    test('Typography_CopyWithAndLerp', () {
      const t = StocklyTypography.standard;
      expect(t.wordmark.fontSize, 30);
      expect(t.wordmark.letterSpacing, -0.3);
      expect(t.numberMedium.fontFamily, FontFamilies.mono);
      expect(t.copyWith(code: t.tagline).code, t.tagline);
      expect(t.copyWith().code, t.code);
      expect(t.lerp(t, 0.5).numberLarge.fontSize, 28);
      expect(t.lerp(null, 0.5), same(t));
    });
  });

  group('SplashTimings', () {
    test('MatchTheBrandTimeline', () {
      expect(SplashTimings.minimum, const Duration(milliseconds: 1800));
      expect(SplashTimings.maximum, const Duration(milliseconds: 3000));
      expect(SplashTimings.scanBeam.start, const Duration(milliseconds: 450));
      expect(SplashTimings.scanBeam.end, const Duration(milliseconds: 1200));
      expect(
        SplashTimings.linesShrink.first.start,
        const Duration(milliseconds: 1150),
      );
      expect(SplashTimings.pixels, hasLength(6));
      expect(SplashTimings.wordmark.start, const Duration(milliseconds: 1750));
      expect(SplashTimings.dotDelays.first, const Duration(milliseconds: 2300));
      final everyStep = [
        SplashTimings.paper,
        ...SplashTimings.linesIn,
        SplashTimings.scanBeam,
        ...SplashTimings.linesShrink,
        ...SplashTimings.pixels,
        SplashTimings.wordmark,
        SplashTimings.tagline,
      ];
      for (final step in everyStep) {
        expect(step.end, lessThanOrEqualTo(SplashTimings.controller));
      }
      expect(SplashCurves.paperPop.transform(1), closeTo(1, 1e-9));
    });
  });

  testWidgets('StocklyMotion_ReadsReduceMotion', (tester) async {
    late StocklyMotion motion;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            motion = StocklyMotion.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(motion.reduced, isTrue);
    expect(motion.resolve(const Duration(seconds: 1)), Duration.zero);
    expect(
      const StocklyMotion(reduced: false).resolve(const Duration(seconds: 1)),
      const Duration(seconds: 1),
    );
  });
}
