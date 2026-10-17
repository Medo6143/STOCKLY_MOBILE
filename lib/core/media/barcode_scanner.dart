import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Reads barcodes with the camera (design §14, `mobile_scanner`). The
/// keyboard-wedge field of the quick-sale screen works without it.
abstract interface class BarcodeScanner {
  /// The barcodes read while [preview] is on screen.
  Stream<String> scan();

  /// The camera view; it starts the camera when shown.
  Widget preview();

  Future<void> dispose();
}

final class MobileBarcodeScanner implements BarcodeScanner {
  new()
    : _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );

  final MobileScannerController _controller;

  @override
  Stream<String> scan() => _controller.barcodes
      .expand((capture) => capture.barcodes)
      .map((barcode) => barcode.rawValue)
      .where((value) => value != null && value.trim().isNotEmpty)
      .map((value) => value!.trim());

  @override
  Widget preview() => MobileScanner(controller: _controller);

  @override
  Future<void> dispose() => _controller.dispose();
}

/// One scanner per camera sheet: disposed when the sheet closes.
final Provider<BarcodeScanner> barcodeScannerProvider =
    Provider.autoDispose<BarcodeScanner>((ref) {
      final scanner = MobileBarcodeScanner();
      ref.onDispose(scanner.dispose);
      return scanner;
    });
