import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/media/barcode_scanner.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The camera barcode scanner (design §14, `BarcodeScanner`): pops with
/// the first barcode read, or nothing when closed.
class BarcodeCameraSheet extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BarcodeCameraSheet> createState() => _BarcodeCameraSheetState();
}

class _BarcodeCameraSheetState extends ConsumerState<BarcodeCameraSheet> {
  StreamSubscription<String>? _reads;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reads = ref.read(barcodeScannerProvider).scan().listen((barcode) {
      if (!_done && mounted) {
        _done = true;
        Navigator.of(context).pop(barcode);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_reads?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final scanner = ref.watch(barcodeScannerProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.salesScanWithCamera,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadiusDirectional.circular(
                  context.radii.lg,
                ),
                child: scanner.preview(),
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              l10n.salesCameraHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
