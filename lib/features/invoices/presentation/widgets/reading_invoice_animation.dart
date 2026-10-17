import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// "Reading the invoice…": a receipt with a scan beam moving down. Under
/// reduce motion it shows its final frame and never ticks (rule 39).
class ReadingInvoiceAnimation extends StatefulWidget {
  const new({super.key});

  @override
  State<ReadingInvoiceAnimation> createState() =>
      _ReadingInvoiceAnimationState();
}

class _ReadingInvoiceAnimationState extends State<ReadingInvoiceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StocklyMotion.of(context).reduced) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller
        ..duration = context.durations.scanBeam
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final size = spacing.huge * 2;
    final beam = spacing.xxs;
    return Semantics(
      label: AppLocalizations.of(context).invoiceProcessingTitle,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Icon(
                Icons.receipt_long_outlined,
                size: size,
                color: colors.muted,
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => PositionedDirectional(
                start: 0,
                end: 0,
                top: (size - beam) * _controller.value,
                child: child!,
              ),
              child: Container(height: beam, color: colors.mint),
            ),
          ],
        ),
      ),
    );
  }
}
