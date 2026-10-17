/// The period filter of the sales history (design §11, S2). "Today"
/// starts at the device's local midnight (checkpoint 2, decision 10).
enum SaleDateRange {
  today,
  lastSevenDays,
  all;

  static const int _sevenDays = 7;

  /// The S2 `from` bound in UTC for the moment [now], or `null` for every
  /// sale. No `to` bound: the history ends now.
  DateTime? fromUtc(DateTime now) {
    final local = now.toLocal();
    final midnight = DateTime(local.year, local.month, local.day);
    return switch (this) {
      SaleDateRange.today => midnight.toUtc(),
      SaleDateRange.lastSevenDays => DateTime(
        midnight.year,
        midnight.month,
        midnight.day - (_sevenDays - 1),
      ).toUtc(),
      SaleDateRange.all => null,
    };
  }
}
