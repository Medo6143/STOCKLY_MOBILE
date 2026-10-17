import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/repositories/invoice_photo_source.dart';

/// Opens the camera, or the gallery as a fallback. `null` = cancelled.
final class TakeInvoicePhotoUseCase {
  const new(this._source);

  final InvoicePhotoSource _source;

  Future<Result<CapturedImage?, Failure>> call({required bool fromGallery}) =>
      fromGallery ? _source.pickFromGallery() : _source.takePhoto();
}
