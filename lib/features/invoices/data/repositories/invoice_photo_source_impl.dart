import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/media/invoice_image_source.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/repositories/invoice_photo_source.dart';

final class InvoicePhotoSourceImpl implements InvoicePhotoSource {
  const new(this._images);

  final InvoiceImageSource _images;

  @override
  Future<Result<CapturedImage?, Failure>> takePhoto() async =>
      _toImage(await _images.capture());

  @override
  Future<Result<CapturedImage?, Failure>> pickFromGallery() async =>
      _toImage(await _images.pickFromGallery());

  Result<CapturedImage?, Failure> _toImage(Result<String?, Failure> result) =>
      switch (result) {
        Ok(value: final path?) => Ok(CapturedImage(path: path)),
        Ok() => const Ok(null),
        Err(:final failure) => Err(failure),
      };
}
