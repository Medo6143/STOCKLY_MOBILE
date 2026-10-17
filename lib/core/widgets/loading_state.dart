import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/skeleton_box.dart';
import 'package:stockly/core/widgets/skeleton_shimmer.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// What a [LoadingState] skeleton looks like.
enum LoadingShape {
  /// Rows of list cards (the default).
  list,

  /// The dashboard: a large card and a grid of small ones.
  cards,

  /// A detail screen: title, a large number and facts.
  detail,

  /// A form: fields in a section card.
  form,

  /// The profile header: an avatar and two lines.
  profile,
}

/// The loading state (rule 34): a skeleton shaped like the content with a
/// subtle shimmer, instead of a bare spinner (design-refresh brief).
class LoadingState extends StatelessWidget {
  const new({this.shape = LoadingShape.list, this.padding, super.key});

  final LoadingShape shape;

  /// Defaults to the screen gutter.
  final EdgeInsetsGeometry? padding;

  static const int _listRows = 6;
  static const int _formFields = 4;
  static const int _detailFacts = 4;
  static const double _title = 0.6;
  static const double _subtitle = 0.35;
  static const double _short = 0.25;
  static const double _half = 0.5;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Semantics(
      label: AppLocalizations.of(context).commonLoading,
      container: true,
      child: SkeletonShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding ?? EdgeInsetsDirectional.all(spacing.md),
          child: switch (shape) {
            LoadingShape.list => _list(context),
            LoadingShape.cards => _cards(context),
            LoadingShape.detail => _detail(context),
            LoadingShape.form => _form(context),
            LoadingShape.profile => _profile(context),
          },
        ),
      ),
    );
  }

  Widget _column(BuildContext context, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, child) in children.indexed) ...[
        if (index > 0) SizedBox(height: context.spacing.sm),
        child,
      ],
    ],
  );

  Widget _lines(BuildContext context, {double first = _title}) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: spacing.md, widthFactor: first),
        SizedBox(height: spacing.xs),
        SkeletonBox(height: spacing.sm, widthFactor: _subtitle),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final spacing = context.spacing;
    return _column(context, [
      for (var i = 0; i < _listRows; i++)
        SurfaceCard(
          child: Row(
            children: [
              SizedBox.square(
                dimension: spacing.xxxl,
                child: SkeletonBox(
                  height: spacing.xxxl,
                  radius: context.radii.md,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(child: _lines(context)),
              SizedBox(width: spacing.sm),
              SizedBox(
                width: spacing.huge,
                child: SkeletonBox(height: spacing.md),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _cards(BuildContext context) {
    final spacing = context.spacing;
    Widget small() => Expanded(
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: spacing.xl, widthFactor: _short),
            SizedBox(height: spacing.sm),
            SkeletonBox(height: spacing.xl, widthFactor: _half),
            SizedBox(height: spacing.xs),
            SkeletonBox(height: spacing.sm, widthFactor: _title),
          ],
        ),
      ),
    );
    Widget pair() => Row(
      children: [
        small(),
        SizedBox(width: spacing.sm),
        small(),
      ],
    );
    return _column(context, [
      SurfaceCard(
        level: 2,
        radius: context.radii.xxl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: spacing.md, widthFactor: _subtitle),
            SizedBox(height: spacing.md),
            SkeletonBox(height: spacing.xxl, widthFactor: _title),
            SizedBox(height: spacing.sm),
            SkeletonBox(height: spacing.sm, widthFactor: _half),
          ],
        ),
      ),
      pair(),
      pair(),
    ]);
  }

  Widget _detail(BuildContext context) {
    final spacing = context.spacing;
    return _column(context, [
      SurfaceCard(
        radius: context.radii.xxl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: spacing.xl, widthFactor: _title),
            SizedBox(height: spacing.md),
            SkeletonBox(height: spacing.sm, widthFactor: _short),
            SizedBox(height: spacing.xs),
            SkeletonBox(height: spacing.xxl, widthFactor: _half),
          ],
        ),
      ),
      SurfaceCard(
        child: Column(
          children: [
            for (var i = 0; i < _detailFacts; i++) ...[
              if (i > 0) SizedBox(height: spacing.md),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: spacing.sm)),
                  SizedBox(width: spacing.xxxl),
                  Expanded(
                    child: SkeletonBox(height: spacing.sm, widthFactor: _half),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _form(BuildContext context) {
    final spacing = context.spacing;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: spacing.md, widthFactor: _subtitle),
          for (var i = 0; i < _formFields; i++) ...[
            SizedBox(height: spacing.md),
            SkeletonBox(height: spacing.huge, radius: context.radii.md),
          ],
        ],
      ),
    );
  }

  Widget _profile(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      children: [
        SizedBox(height: spacing.xl),
        SkeletonBox(height: spacing.huge * 2, circle: true),
        SizedBox(height: spacing.md),
        SkeletonBox(
          height: spacing.lg,
          widthFactor: _half,
          alignment: AlignmentDirectional.center,
        ),
        SizedBox(height: spacing.xs),
        SkeletonBox(
          height: spacing.sm,
          widthFactor: _title,
          alignment: AlignmentDirectional.center,
        ),
        SizedBox(height: spacing.xl),
        _list(context),
      ],
    );
  }
}
