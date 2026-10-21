/// The server's `items[i].*` field errors (`ValidationFailure.fieldErrors`) on
/// the lines that were sent, for the screens that send lines (quick sale,
/// invoice review).
abstract final class LineFieldErrors {
  /// `items[2].quantity` → index 2 of the sent lines.
  static final RegExp _itemField = RegExp(r'^items\[(\d+)\]');

  /// Messages by line: [lineIds] holds, for each sent line in order, the id
  /// the screen shows its messages on. Keys that are not an item, or name a
  /// line that was not sent, are left out.
  static Map<int, List<String>> byLine(
    Map<String, List<String>> fieldErrors,
    List<int> lineIds,
  ) {
    final messages = <int, List<String>>{};
    for (final MapEntry(:key, :value) in fieldErrors.entries) {
      final index = int.tryParse(_itemField.firstMatch(key)?.group(1) ?? '');
      if (index == null || index >= lineIds.length) {
        continue;
      }
      final id = lineIds[index];
      messages[id] = [...?messages[id], ...value];
    }
    return messages;
  }
}
