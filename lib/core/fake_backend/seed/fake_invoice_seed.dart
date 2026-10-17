import 'package:decimal/decimal.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_invoice_records.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';

/// Invoices of the fake pharmacy in every status (design §12.1), and what
/// the fake AI reads from new scans.
abstract final class FakeInvoiceSeed {
  static const String _idPrefix = '0192f0a0-6c1e-7b3a-9d2e-e0000000';
  static const String _requestPrefix = '0192f0a0-6c1e-7b3a-9d2e-f0000000';
  static const int _idDigits = 4;
  static const int _moneyScale = 2;

  /// A `NeedsReview` invoice: matched lines (one in boxes), a line without
  /// a product, a new product, and a total that does not match.
  static const String needsReviewId = '${_idPrefix}0001';

  /// A confirmed invoice.
  static const String confirmedId = '${_idPrefix}0002';

  /// A failed scan.
  static const String failedId = '${_idPrefix}0003';

  /// An invoice still being read; it turns `NeedsReview` after the
  /// processing delay.
  static const String processingId = '${_idPrefix}0004';

  /// A `NeedsReview` invoice where no line was read.
  static const String emptyId = '${_idPrefix}0005';

  /// What the fake AI reads from new scans, in turn: a pharmacy invoice
  /// with a mismatching total and an unknown product, a clean one, and an
  /// unreadable photo.
  static const List<FakeExtraction> extractions = [
    FakeExtraction(
      supplierName: 'شركة الأدوية المتحدة',
      invoiceNumber: 'INV-2051',
      invoiceDate: '2026-10-11',
      totalAmount: '320.00',
      lines: [
        FakeExtractedLine(
          'بنادول اكسترا ٢٠ قرص',
          '10.000',
          '12.00',
          expiryDate: '2027-03-31',
          batchNo: 'B12',
        ),
        FakeExtractedLine('كونجستال شريط', '5.000', '14.00'),
        FakeExtractedLine('سيتال شراب ١٠٠ مل', '6.000', '18.50'),
      ],
    ),
    FakeExtraction(
      supplierName: 'مخازن النيل للأدوية',
      invoiceNumber: 'NL-778',
      invoiceDate: '2026-10-12',
      totalAmount: '255.00',
      lines: [
        FakeExtractedLine('بروفين 400 أقراص', '4.000', '30.00'),
        FakeExtractedLine(
          'فيتامين سي 1000 فوار',
          '3.000',
          '45.00',
          expiryDate: '2027-01-31',
        ),
      ],
    ),
    FakeExtraction(
      failureReasonAr: 'الصورة مش واضحة. صوّرها تاني في نور أحسن.',
      failureReasonEn: 'The photo is not clear. Take it again in better light.',
    ),
  ];

  /// Adds the seeded invoices of [shopId]; [processingDelay] is when the
  /// `Processing` one is read.
  static void addTo(
    FakeBackendState state, {
    required String shopId,
    required DateTime now,
    required Duration processingDelay,
  }) {
    FakeProduct product(String name) =>
        state.products.firstWhere((p) => p.shopId == shopId && p.name == name);
    final panadol = product('بنادول اكسترا');
    final congestal = product('كونجستال');
    final brufen = product('بروفين 400');
    final vitaminC = product('فيتامين سي 1000');
    var serial = 0;
    String itemId() =>
        '${_idPrefix}1${(++serial).toString().padLeft(_idDigits - 1, '0')}';
    FakeInvoiceItem item(
      int lineNo,
      String rawName,
      String quantity,
      String unitPrice, {
      FakeProduct? of,
      FakeUnit? unit,
      String? confidence,
      FakeNewProduct? newProduct,
      String? expiryDate,
      String? batchNo,
    }) {
      final q = Decimal.parse(quantity);
      final p = Decimal.parse(unitPrice);
      return FakeInvoiceItem(
        id: itemId(),
        lineNo: lineNo,
        rawName: rawName,
        productId: of?.id,
        productUnitId: of == null ? null : (unit ?? of.baseUnit).id,
        quantity: q,
        unitPrice: p,
        lineTotal: (q * p).round(scale: _moneyScale),
        expiryDate: expiryDate,
        batchNo: batchNo,
        matchConfidence: confidence,
        newProduct: newProduct,
      );
    }

    String request(int n) =>
        '$_requestPrefix${n.toString().padLeft(_idDigits, '0')}';
    const day = Duration(days: 1);
    state.invoices.addAll([
      FakeInvoice(
        id: needsReviewId,
        shopId: shopId,
        clientRequestId: request(1),
        status: FakeInvoiceStatuses.needsReview,
        createdAt: now.subtract(day * 2),
        processedAt: now.subtract(day * 2),
        supplierName: 'شركة الأدوية المتحدة',
        invoiceNumber: 'INV-1043',
        invoiceDate: '2026-10-10',
        totalAmount: Decimal.parse('1250.00'),
        warnings: [FakeInvoiceWarnings.totalMismatch],
        items: [
          item(
            1,
            'بنادول اكسترا ٢٠ قرص علبة',
            '10.000',
            '36.00',
            of: panadol,
            unit: panadol.units.last,
            confidence: '0.95',
            expiryDate: '2027-03-31',
            batchNo: 'B12',
          ),
          item(
            2,
            'كونجستال',
            '12.000',
            '14.00',
            of: congestal,
            confidence: '0.88',
          ),
          item(3, 'مرهم جلد ٣٠ جم', '5.000', '22.50', confidence: '0.40'),
          item(
            4,
            'سيتال شراب ١٠٠ مل',
            '6.000',
            '18.50',
            newProduct: FakeNewProduct(
              name: 'سيتال شراب',
              baseUnitName: 'زجاجة',
              sellPrice: Decimal.parse('25.00'),
            ),
          ),
        ],
      ),
      FakeInvoice(
        id: confirmedId,
        shopId: shopId,
        clientRequestId: request(2),
        status: FakeInvoiceStatuses.confirmed,
        createdAt: now.subtract(day * 6),
        processedAt: now.subtract(day * 6),
        confirmedAt: now.subtract(day * 5),
        supplierName: 'مخازن النيل للأدوية',
        invoiceNumber: 'NL-512',
        invoiceDate: '2026-10-05',
        totalAmount: Decimal.parse('255.00'),
        items: [
          item(
            1,
            'بروفين 400',
            '4.000',
            '30.00',
            of: brufen,
            confidence: '0.97',
          ),
          item(
            2,
            'فيتامين سي 1000',
            '3.000',
            '45.00',
            of: vitaminC,
            confidence: '0.93',
          ),
        ],
      ),
      FakeInvoice(
        id: failedId,
        shopId: shopId,
        clientRequestId: request(3),
        status: FakeInvoiceStatuses.failed,
        createdAt: now.subtract(day * 3),
        processedAt: now.subtract(day * 3),
        failureReason: 'الصورة مش واضحة. صوّرها تاني في نور أحسن.',
      ),
      FakeInvoice(
        id: processingId,
        shopId: shopId,
        clientRequestId: request(4),
        status: FakeInvoiceStatuses.processing,
        createdAt: now,
        readyAt: now.add(processingDelay),
        pending: extractions[1],
      ),
      FakeInvoice(
        id: emptyId,
        shopId: shopId,
        clientRequestId: request(5),
        status: FakeInvoiceStatuses.needsReview,
        createdAt: now.subtract(day),
        processedAt: now.subtract(day),
        warnings: [FakeInvoiceWarnings.unreadableLines],
      ),
    ]);
  }
}
