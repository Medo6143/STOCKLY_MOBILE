import 'package:freezed_annotation/freezed_annotation.dart';

part 'captured_image.freezed.dart';

/// A photo just taken, still in a temporary file at [path].
@freezed
abstract class CapturedImage with _$CapturedImage {
  const factory({required String path}) = _CapturedImage;
}
