import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/domain/entities/sale_input_rules.dart';
import 'package:stockly/features/sales/domain/entities/sale_outcome.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/presentation/providers/quick_sale_state.dart';
import 'package:stockly/features/sales/presentation/providers/sale_list_notifier.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';

/// The quick-sale cart (design §11 cart rules, §6.8): lines by barcode
/// (P12) or search (P1 + P2), quantity and price override per line, and
/// the submit (S1). The sale's `clientRequestId` is created on the first
/// submit and reused on every retry; an unknown outcome locks the cart
/// until Retry or Discard. Kept alive while the cart has lines or a sale
/// is in flight or locked.
final class QuickSaleNotifier extends Notifier<QuickSaleState> {
  KeepAliveLink? _keepAlive;

  /// `items[2].quantity` → index 2 of the sent lines.
  static final RegExp _itemField = RegExp(r'^items\[(\d+)\]');

  @override
  QuickSaleState build() {
    ref.onDispose(() => _keepAlive = null);
    return const QuickSaleState();
  }

  void _set(QuickSaleState next) {
    state = next;
    final hold = next.lines.isNotEmpty || !next.isEditable;
    if (hold) {
      _keepAlive ??= ref.keepAlive();
    } else {
      _keepAlive?.close();
      _keepAlive = null;
    }
  }

  /// Reopens the shop's sale whose outcome is unknown, locked (design
  /// §6.8). Nothing changes while the cart is in use.
  Future<void> restorePending() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || !state.isEditable || state.lines.isNotEmpty) {
      return;
    }
    final pending = await ref
        .read(getPendingSaleUseCaseProvider)
        .call(session.shop.id);
    if (!ref.mounted ||
        pending == null ||
        !state.isEditable ||
        state.lines.isNotEmpty) {
      return;
    }
    _set(
      state.copyWith(
        phase: QuickSalePhase.lockedUnknownOutcome,
        clientRequestId: pending.request.clientRequestId,
        lockedRequest: pending.request,
        lockedSince: pending.createdAt,
      ),
    );
  }

  /// A scanned or typed barcode (P12). Scanning a barcode already in the
  /// cart adds 1 to its line.
  Future<void> addBarcode(String raw) async {
    final barcode = raw.trim();
    if (barcode.isEmpty || !state.isEditable) {
      return;
    }
    _startLookup();
    final result = await ref.read(lookupBarcodeUseCaseProvider).call(barcode);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(value: final lookup):
        _endLookup();
        _addLine(
          product: lookup.product,
          unit: lookup.unit,
          units: [lookup.unit],
          unitsLoaded: false,
        );
      case Err(:final failure):
        _endLookup(failure: failure);
    }
  }

  /// A product picked from the search (P1); its units come from P2 and the
  /// base unit is chosen.
  Future<void> addProduct(ProductListItem product) async {
    if (!state.isEditable) {
      return;
    }
    _startLookup();
    final result = await ref.read(getProductUseCaseProvider).call(product.id);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(value: final detail):
        _endLookup();
        _addLine(
          product: product.copyWith(quantity: detail.quantity),
          unit: detail.baseUnit,
          units: detail.units,
          unitsLoaded: true,
        );
      case Err(:final failure):
        _endLookup(failure: failure);
    }
  }

  void _startLookup() => _set(
    state.copyWith(
      lookupsRunning: state.lookupsRunning + 1,
      lookupFailure: null,
    ),
  );

  void _endLookup({Failure? failure}) => _set(
    state.copyWith(
      lookupsRunning: state.lookupsRunning - 1,
      lookupFailure: failure,
    ),
  );

  void _addLine({
    required ProductListItem product,
    required ProductUnit unit,
    required List<ProductUnit> units,
    required bool unitsLoaded,
  }) {
    final current = state;
    if (!current.isEditable) {
      return;
    }
    final index = current.lines.indexWhere(
      (line) => line.productId == product.id && line.unit.id == unit.id,
    );
    if (index >= 0) {
      final line = current.lines[index];
      final quantity = (line.quantity ?? Quantity.zero) + Quantity.one;
      _set(
        current.copyWith(
          lines: [...current.lines]
            ..[index] = line.copyWith(
              quantity: quantity,
              quantityText: DecimalFormatter.formatQuantity(quantity),
              quantityIssue: null,
            ),
          lineErrors: {...current.lineErrors}..remove(line.key),
        ),
      );
      return;
    }
    if (current.lines.length >= SaleRules.maxLines) {
      _set(current.copyWith(lineLimitReached: true));
      return;
    }
    _set(
      current.copyWith(
        nextLineKey: current.nextLineKey + 1,
        lines: [
          ...current.lines,
          CartLine(
            key: current.nextLineKey,
            productId: product.id,
            productName: product.name,
            unit: unit,
            units: units,
            unitsLoaded: unitsLoaded,
            stock: product.quantity,
            baseUnitName: product.baseUnit.name,
            quantity: Quantity.one,
            quantityText: DecimalFormatter.formatQuantity(Quantity.one),
          ),
        ],
      ),
    );
  }

  void _editLine(int key, CartLine Function(CartLine line) change) {
    final current = state;
    if (!current.isEditable) {
      return;
    }
    final index = current.lines.indexWhere((line) => line.key == key);
    if (index < 0) {
      return;
    }
    _set(
      current.copyWith(
        lines: [...current.lines]..[index] = change(current.lines[index]),
        lineErrors: {...current.lineErrors}..remove(key),
        lineMessages: {...current.lineMessages}..remove(key),
      ),
    );
  }

  /// Loads every unit of the line's product (P2) for the unit picker; a
  /// line added by barcode only knows the scanned unit.
  Future<void> loadUnits(int key) async {
    final line = state.lines.where((l) => l.key == key).firstOrNull;
    if (line == null || line.unitsLoaded || !state.isEditable) {
      return;
    }
    _startLookup();
    final result = await ref
        .read(getProductUseCaseProvider)
        .call(line.productId);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(value: final detail):
        _endLookup();
        _editLine(
          key,
          (l) => l.copyWith(units: detail.units, unitsLoaded: true),
        );
      case Err(:final failure):
        _endLookup(failure: failure);
    }
  }

  /// Picks another unit of the line's product; a typed price override is
  /// dropped because it was a price of the other unit.
  void setUnit(int key, String unitId) => _editLine(key, (line) {
    final unit = line.units.where((u) => u.id == unitId).firstOrNull;
    return unit == null || unit.id == line.unit.id
        ? line
        : line.copyWith(
            unit: unit,
            priceText: '',
            priceOverride: null,
            priceIssue: null,
          );
  });

  void setQuantity(int key, String text) => _editLine(key, (line) {
    final parsed = SaleInputRules.quantity(text);
    return line.copyWith(
      quantityText: text,
      quantity: parsed.value,
      quantityIssue: parsed.issue,
    );
  });

  /// The cashier's price; blank charges the unit's sell price.
  void setPrice(int key, String text) => _editLine(key, (line) {
    final parsed = SaleInputRules.priceOverride(text);
    return line.copyWith(
      priceText: text,
      priceOverride: parsed.value,
      priceIssue: parsed.issue,
    );
  });

  void removeLine(int key) {
    final current = state;
    if (!current.isEditable) {
      return;
    }
    _set(
      current.copyWith(
        lines: current.lines.where((line) => line.key != key).toList(),
        lineErrors: {...current.lineErrors}..remove(key),
        lineMessages: {...current.lineMessages}..remove(key),
        lineLimitReached: false,
      ),
    );
  }

  void setNote(String text) {
    if (state.isEditable) {
      _set(state.copyWith(note: text));
    }
  }

  /// Empties the cart.
  void clear() {
    if (state.isEditable) {
      _set(_empty());
    }
  }

  QuickSaleState _empty() => QuickSaleState(
    nextLineKey: state.nextLineKey,
    lastSubmission: state.lastSubmission,
    submissionCount: state.submissionCount,
  );

  /// Sends the cart (S1). Lines that cannot be sent are flagged first and
  /// nothing is sent while one exists.
  Future<void> submit() async {
    final current = state;
    final session = ref.read(currentSessionProvider);
    if (session == null || !current.isEditable || current.lines.isEmpty) {
      return;
    }
    final invalid = {
      for (final line in current.lines)
        if (!line.isValid) line.key,
    };
    if (invalid.isNotEmpty) {
      _set(current.copyWith(lineErrors: invalid, failure: null));
      return;
    }
    final note = current.note.trim();
    await _send(
      SaleRequest(
        clientRequestId:
            current.clientRequestId ?? ref.read(uuidGeneratorProvider).v4(),
        note: note.isEmpty ? null : note,
        items: [for (final line in current.lines) line.toRequestItem()],
      ),
      session,
    );
  }

  /// Sends the locked sale again: same `clientRequestId`, same body.
  Future<void> retry() async {
    final request = state.lockedRequest;
    final session = ref.read(currentSessionProvider);
    if (!state.isLocked || request == null || session == null) {
      return;
    }
    await _send(request, session);
  }

  /// Drops the locked sale and empties the cart. If an earlier attempt did
  /// record it, it is in the sales list.
  Future<void> discard() async {
    final id = state.clientRequestId;
    if (!state.isLocked || id == null) {
      return;
    }
    await ref.read(discardPendingSaleUseCaseProvider).call(id);
    if (ref.mounted) {
      _set(_empty());
    }
  }

  Future<void> _send(SaleRequest request, Session session) async {
    final sending = state.copyWith(
      phase: QuickSalePhase.submitting,
      clientRequestId: request.clientRequestId,
      failure: null,
      lineErrors: const {},
      lineMessages: const {},
    );
    _set(sending);
    final result = await ref
        .read(submitSaleUseCaseProvider)
        .call(request, shopId: session.shop.id, userId: session.user.id);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(value: final submission):
        ref
          ..invalidate(saleListProvider)
          ..invalidate(productListProvider)
          ..invalidate(dashboardSummaryProvider);
        _set(
          _empty().copyWith(
            lastSubmission: submission,
            submissionCount: state.submissionCount + 1,
          ),
        );
      case Err(:final failure) when failure.leavesSaleOutcomeUnknown:
        _set(
          state.copyWith(
            phase: QuickSalePhase.lockedUnknownOutcome,
            lockedRequest: request,
            lockedSince: state.lockedSince ?? ref.read(clockProvider).now(),
            failure: failure,
          ),
        );
      case Err(:final failure):
        _set(
          state.copyWith(
            phase: QuickSalePhase.editing,
            clientRequestId: null,
            lockedRequest: null,
            lockedSince: null,
            failure: failure,
            lineMessages: _lineMessages(failure, sending),
          ),
        );
    }
  }

  /// Server messages of `items[i].*` keys, by the key of line `i`.
  Map<int, List<String>> _lineMessages(Failure failure, QuickSaleState sent) {
    if (failure is! ValidationFailure) {
      return const {};
    }
    final messages = <int, List<String>>{};
    for (final MapEntry(:key, :value) in failure.fieldErrors.entries) {
      final index = int.tryParse(_itemField.firstMatch(key)?.group(1) ?? '');
      if (index == null || index >= sent.lines.length) {
        continue;
      }
      final lineKey = sent.lines[index].key;
      messages[lineKey] = [...?messages[lineKey], ...value];
    }
    return messages;
  }
}

final NotifierProvider<QuickSaleNotifier, QuickSaleState> quickSaleProvider =
    NotifierProvider.autoDispose<QuickSaleNotifier, QuickSaleState>(
      QuickSaleNotifier.new,
    );
