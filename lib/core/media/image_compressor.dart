import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';

/// Resizes and re-encodes a photo (design §6.1, `flutter_image_compress`):
/// EXIF orientation applied, EXIF metadata stripped, JPEG.
abstract interface class ImageCompressor {
  /// The JPEG bytes of [path], at most [maxLongEdge] pixels on the long edge
  /// when the source already fits a square of that size (the image source
  /// asks the camera for that).
  Future<Result<Uint8List, Failure>> compress(
    String path, {
    required int maxLongEdge,
    required int jpegQuality,
  });
}

final class NativeImageCompressor implements ImageCompressor {
  const new();

  @override
  Future<Result<Uint8List, Failure>> compress(
    String path, {
    required int maxLongEdge,
    required int jpegQuality,
  }) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: maxLongEdge,
      minHeight: maxLongEdge,
      quality: jpegQuality,
    );
    return bytes == null
        ? const Err(LocalFailure(LocalFailureReason.storage))
        : Ok(bytes);
  }
}

final imageCompressorProvider = Provider<ImageCompressor>(
  (ref) => const NativeImageCompressor(),
);
