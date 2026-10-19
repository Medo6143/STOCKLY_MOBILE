/// Why a wallet phone number cannot be sent.
enum WalletPhoneIssue { required, invalid }

/// The B3 `walletPhone` rule: an Egyptian mobile number
/// (`^01[0125][0-9]{8}$`). Arabic-Indic and Persian digits are accepted and
/// sent as Western digits; spaces and dashes are dropped. The server checks
/// it again.
abstract final class WalletPhoneRules {
  static final RegExp _egyptianMobile = RegExp(r'^01[0125][0-9]{8}$');
  static final RegExp _separators = RegExp(r'[\s\-]');

  static const int _arabicIndicZero = 0x0660;
  static const int _extendedArabicIndicZero = 0x06F0;
  static const int _asciiZero = 0x30;
  static const int _digitCount = 10;

  /// Western digits, no spaces or dashes.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      if (rune >= _arabicIndicZero && rune < _arabicIndicZero + _digitCount) {
        buffer.writeCharCode(_asciiZero + rune - _arabicIndicZero);
      } else if (rune >= _extendedArabicIndicZero &&
          rune < _extendedArabicIndicZero + _digitCount) {
        buffer.writeCharCode(_asciiZero + rune - _extendedArabicIndicZero);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(_separators, '');
  }

  /// `null` when the normalized [raw] is a valid number.
  static WalletPhoneIssue? check(String raw) {
    final phone = normalize(raw);
    if (phone.isEmpty) {
      return WalletPhoneIssue.required;
    }
    return _egyptianMobile.hasMatch(phone) ? null : WalletPhoneIssue.invalid;
  }
}
