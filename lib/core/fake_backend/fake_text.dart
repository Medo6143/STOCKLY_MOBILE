/// The backend's Arabic search key (`ArabicTextNormalizer`): tashkeel,
/// superscript alef and tatweel removed; أ إ آ ٱ → ا, ة → ه, ى → ي;
/// Arabic-Indic and Persian digits → 0-9; Latin lower-case; trimmed with
/// whitespace collapsed.
abstract final class FakeText {
  static const int _fathatan = 0x064B;
  static const int _sukun = 0x0652;
  static const int _superscriptAlef = 0x0670;
  static const int _tatweel = 0x0640;
  static const int _alef = 0x0627;
  static const Set<int> _alefForms = {0x0623, 0x0625, 0x0622, 0x0671};
  static const int _tehMarbuta = 0x0629;
  static const int _heh = 0x0647;
  static const int _alefMaksura = 0x0649;
  static const int _yeh = 0x064A;
  static const int _arabicIndicZero = 0x0660;
  static const int _persianZero = 0x06F0;
  static const int _asciiZero = 0x30;
  static const int _digitCount = 10;

  static final RegExp _whitespace = RegExp(r'\s');

  static String normalize(String text) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final rune in text.runes) {
      if (rune >= _fathatan && rune <= _sukun ||
          rune == _superscriptAlef ||
          rune == _tatweel) {
        continue;
      }
      final char = String.fromCharCode(rune);
      if (_whitespace.hasMatch(char)) {
        pendingSpace = buffer.isNotEmpty;
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.write(_map(rune, char));
    }
    return buffer.toString();
  }

  static String _map(int rune, String char) {
    if (_alefForms.contains(rune)) {
      return String.fromCharCode(_alef);
    }
    if (rune == _tehMarbuta) {
      return String.fromCharCode(_heh);
    }
    if (rune == _alefMaksura) {
      return String.fromCharCode(_yeh);
    }
    if (rune >= _arabicIndicZero && rune < _arabicIndicZero + _digitCount) {
      return String.fromCharCode(_asciiZero + rune - _arabicIndicZero);
    }
    if (rune >= _persianZero && rune < _persianZero + _digitCount) {
      return String.fromCharCode(_asciiZero + rune - _persianZero);
    }
    return char.toLowerCase();
  }
}
