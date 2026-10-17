import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';

/// Takes the invoice photo. `null` means the user cancelled.
abstract interface class InvoicePhotoSource {
  Future<Result<CapturedImage?, Failure>> takePhoto();

  Future<Result<CapturedImage?, Failure>> pickFromGallery();
}
