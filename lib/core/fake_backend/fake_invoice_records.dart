import 'package:decimal/decimal.dart';

/// Contract `InvoiceStatus` values.
abstract final class FakeInvoiceStatuses {
  static const String processing = 'Processing';
  static const String needsReview = 'NeedsReview';
  static const String confirmed = 'Confirmed';
  static const String failed = 'Failed';

  static const Set<String> all = {processing, needsReview, confirmed, failed};
}

/// Contract `InvoiceWarning` values.
abstract final class FakeInvoiceWarnings {
  static const String totalMismatch = 'TotalMismatch';
  static const String itemCapExceeded = 'ItemCapExceeded';
  static const String unreadableLines = 'UnreadableLines';
  static const String duplicateInvoiceNumber = 'DuplicateInvoiceNumber';

  /// Set by the extraction only; a review save keeps them.
  static const Set<String> extractionOnly = {itemCapExceeded, unreadableLines};
}

/// What an invoice line will create on confirm (contract I4 `newProduct`).
final class FakeNewProduct {
  const new({
    required this.name,
    required this.baseUnitName,
    required this.sellPrice,
  });

  final String name;
  final String baseUnitName;
  final Decimal sellPrice;
}

/// One invoice line. [quantity] is in the line's unit; [lineTotal] is
/// `quantity × unitPrice` rounded to 2 decimals away from zero.
final class FakeInvoiceItem {
  const new({
    required this.id,
    required this.lineNo,
    required this.rawName,
    required this.productId,
    required this.productUnitId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.expiryDate,
    required this.batchNo,
    required this.matchConfidence,
    required this.newProduct,
  });

  final String id;
  final int lineNo;
  final String rawName;
  final String? productId;
  final String? productUnitId;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal lineTotal;

  /// `yyyy-MM-dd`.
  final String? expiryDate;
  final String? batchNo;

  /// `0.00`–`1.00` with 2 decimals.
  final String? matchConfidence;
  final FakeNewProduct? newProduct;
}

/// One line the fake AI reads from a photo.
final class FakeExtractedLine {
  const new(
    this.rawName,
    this.quantity,
    this.unitPrice, {
    this.expiryDate,
    this.batchNo,
  });

  final String rawName;
  final String quantity;
  final String unitPrice;
  final String? expiryDate;
  final String? batchNo;
}

/// What the fake AI reads from a photo: header and lines, or a failure
/// reason (the scan fails).
final class FakeExtraction {
  const new({
    this.supplierName,
    this.invoiceNumber,
    this.invoiceDate,
    this.totalAmount,
    this.lines = const [],
    this.warnings = const [],
    this.failureReasonAr,
    this.failureReasonEn,
  });

  final String? supplierName;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? totalAmount;
  final List<FakeExtractedLine> lines;

  /// Extraction warnings (`ItemCapExceeded`, `UnreadableLines`).
  final List<String> warnings;
  final String? failureReasonAr;
  final String? failureReasonEn;

  bool get fails => failureReasonAr != null;
}

/// An invoice of the fake shop. While `Processing`, [pending] is applied
/// once the fake clock reaches [readyAt] (design §12.1).
final class FakeInvoice {
  new({
    required this.id,
    required this.shopId,
    required this.clientRequestId,
    required this.status,
    required this.createdAt,
    this.supplierName,
    this.invoiceNumber,
    this.invoiceDate,
    this.totalAmount,
    this.failureReason,
    this.processedAt,
    this.confirmedAt,
    this.readyAt,
    this.pending,
    this.language = 'ar',
    List<String>? warnings,
    List<FakeInvoiceItem>? items,
  }) : warnings = warnings ?? [],
       items = items ?? [];

  final String id;
  final String shopId;
  final String clientRequestId;
  String status;
  String? supplierName;
  String? invoiceNumber;

  /// `yyyy-MM-dd`.
  String? invoiceDate;
  Decimal? totalAmount;
  List<String> warnings;
  String? failureReason;
  List<FakeInvoiceItem> items;
  final DateTime createdAt;
  DateTime? processedAt;
  DateTime? confirmedAt;
  final DateTime? readyAt;
  FakeExtraction? pending;

  /// `Accept-Language` of the scan, for the failure reason.
  final String language;
}
