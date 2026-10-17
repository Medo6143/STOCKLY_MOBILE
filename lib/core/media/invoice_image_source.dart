import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';

/// Takes the invoice photo (design §14, `image_picker`). The value is the
/// path of a temporary file, or `null` when the user cancelled.
abstract interface class InvoiceImageSource {
  /// The system camera.
  Future<Result<String?, Failure>> capture();

  /// The gallery, as a fallback when there is no camera.
  Future<Result<String?, Failure>> pickFromGallery();
}

/// `image_picker` already limits the long edge, so the compressor never
/// has to decode a full-size photo.
final class PickerInvoiceImageSource implements InvoiceImageSource {
  const new(this._picker);

  final ImagePicker _picker;

  /// `image_picker` error codes that mean the user refused access.
  static const Set<String> _deniedCodes = {
    'camera_access_denied',
    'photo_access_denied',
  };

  @override
  Future<Result<String?, Failure>> capture() => _pick(ImageSource.camera);

  @override
  Future<Result<String?, Failure>> pickFromGallery() =>
      _pick(ImageSource.gallery);

  Future<Result<String?, Failure>> _pick(ImageSource source) async {
    final edge = ScanLimits.maxLongEdgePx.toDouble();
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: edge,
        maxHeight: edge,
        requestFullMetadata: false,
      );
      return Ok(file?.path);
    } on PlatformException catch (e) {
      return Err(
        LocalFailure(
          _deniedCodes.contains(e.code)
              ? LocalFailureReason.cameraDenied
              : LocalFailureReason.storage,
        ),
      );
    }
  }
}

final invoiceImageSourceProvider = Provider<InvoiceImageSource>(
  (ref) => PickerInvoiceImageSource(ImagePicker()),
);
