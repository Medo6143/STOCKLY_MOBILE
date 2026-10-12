import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/fake_backend/fake_text.dart';

/// The fake backend's search key matches the backend's Arabic normalizer.
void main() {
  test('Normalize_ArabicLettersDigitsAndSpaces', () {
    expect(FakeText.normalize('  أَدْفانـــس  '), 'ادفانس');
    expect(FakeText.normalize('إبرة آمنة ٱلكبرى'), 'ابره امنه الكبري');
    expect(FakeText.normalize('بنادول   ٥٠٠ ۱۰'), 'بنادول 500 10');
    expect(FakeText.normalize('Panadol EXTRA'), 'panadol extra');
  });

  test('Normalize_OnlyMarks_Empty', () {
    expect(FakeText.normalize(' ـ َ '), isEmpty);
  });
}
