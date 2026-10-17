import 'package:flutter/material.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_elevation.dart';
import 'package:stockly/core/theme/stockly_radii.dart';
import 'package:stockly/core/theme/stockly_spacing.dart';
import 'package:stockly/core/theme/stockly_typography.dart';
import 'package:stockly/core/theme/tokens.dart';

/// Material themes built from the brand extensions (design §7.1), so
/// Material widgets match the tokens. The component themes give every
/// screen the refreshed look (design-refresh brief): pill buttons, filled
/// rounded fields with a mint focus ring, soft chips, a pill indicator in
/// the navigation bar and rounded sheets and dialogs.
abstract final class AppTheme {
  static ThemeData light() => _build(
    StocklyColors.light,
    StocklyElevation.light(StocklyColors.light),
    Brightness.light,
  );

  static ThemeData dark() => _build(
    StocklyColors.dark,
    StocklyElevation.dark(StocklyColors.dark),
    Brightness.dark,
  );

  static ThemeData _build(
    StocklyColors colors,
    StocklyElevation elevation,
    Brightness brightness,
  ) {
    const spacing = StocklySpacing.standard;
    const radii = StocklyRadii.standard;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.mint,
      onPrimary: colors.onMint,
      primaryContainer: colors.mintSoft,
      onPrimaryContainer: colors.ink,
      secondary: colors.ink,
      onSecondary: colors.surface,
      secondaryContainer: colors.mintSoft,
      onSecondaryContainer: colors.ink,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.muted,
      surfaceContainerHighest: colors.background,
      outline: colors.line,
      outlineVariant: colors.line,
      error: colors.danger,
      onError: Tokens.white,
    );
    final textTheme = StocklyTypography.textTheme().apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );
    final label = textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    const stadium = StadiumBorder();
    final buttonSize = Size(spacing.huge, spacing.huge);
    final buttonPadding = EdgeInsetsDirectional.symmetric(
      horizontal: spacing.xl,
    );
    OutlineInputBorder field(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.raisedSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsetsDirectional.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.lg),
          side: elevation.border ?? BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        contentPadding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.md,
          vertical: spacing.md,
        ),
        border: field(colors.line),
        enabledBorder: field(colors.line),
        disabledBorder: field(colors.line),
        focusedBorder: field(colors.mint, width: 2),
        errorBorder: field(colors.danger),
        focusedErrorBorder: field(colors.danger, width: 2),
        prefixIconColor: colors.muted,
        suffixIconColor: colors.muted,
        labelStyle: textTheme.bodyLarge?.copyWith(color: colors.muted),
        floatingLabelStyle: textTheme.bodyLarge?.copyWith(color: colors.ink),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: stadium,
          minimumSize: buttonSize,
          padding: buttonPadding,
          textStyle: label,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: stadium,
          minimumSize: buttonSize,
          padding: buttonPadding,
          textStyle: label,
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.line),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: stadium,
          textStyle: label,
          foregroundColor: colors.ink,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.mint,
        foregroundColor: colors.onMint,
        shape: stadium,
        extendedTextStyle: label,
      ),
      chipTheme: ChipThemeData(
        shape: stadium,
        side: BorderSide(color: colors.line),
        backgroundColor: colors.raisedSurface,
        selectedColor: colors.mintSoft,
        checkmarkColor: colors.ink,
        labelStyle: textTheme.labelLarge?.copyWith(color: colors.ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.mintSoft,
          selectedForegroundColor: colors.ink,
          foregroundColor: colors.muted,
          side: BorderSide(color: colors.line),
          textStyle: label,
          minimumSize: buttonSize,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.mintSoft,
        indicatorShape: stadium,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.ink
                : colors.muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.ink
                : colors.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radii.xxl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.xxl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.background,
        ),
        actionTextColor: colors.mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.lg),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.line, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.mint,
        linearTrackColor: colors.mintSoft,
      ),
      extensions: [
        colors,
        elevation,
        StocklySpacing.standard,
        StocklyRadii.standard,
        StocklyDurations.standard,
        StocklyTypography.standard,
      ],
    );
  }
}

/// Short access to the brand extensions.
extension StocklyThemeX on BuildContext {
  StocklyColors get colors => Theme.of(this).extension<StocklyColors>()!;
  StocklySpacing get spacing => Theme.of(this).extension<StocklySpacing>()!;
  StocklyRadii get radii => Theme.of(this).extension<StocklyRadii>()!;
  StocklyDurations get durations =>
      Theme.of(this).extension<StocklyDurations>()!;
  StocklyTypography get typo => Theme.of(this).extension<StocklyTypography>()!;
  StocklyElevation get elevation =>
      Theme.of(this).extension<StocklyElevation>()!;
}
