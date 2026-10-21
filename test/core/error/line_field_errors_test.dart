import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/line_field_errors.dart';

void main() {
  test('byLine_ItemErrors_OnTheIdOfTheSentLine', () {
    final messages = LineFieldErrors.byLine(
      {
        'items[0].quantity': ['must be positive'],
        'items[2].unitPrice': ['too many decimals'],
        'items[2].quantity': ['too large'],
      },
      [7, 9, 12],
    );

    expect(messages, {
      7: ['must be positive'],
      12: ['too many decimals', 'too large'],
    });
  });

  test('byLine_NotAnItemOrOutOfRange_Ignored', () {
    final messages = LineFieldErrors.byLine(
      {
        'note': ['too long'],
        'items[2].quantity': ['one past the last line'],
        'items[5].quantity': ['line not sent'],
        'itemsX[0].quantity': ['other field'],
      },
      [1, 2],
    );

    expect(messages, isEmpty);
  });
}
