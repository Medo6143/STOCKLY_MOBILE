/// Wraps [text] in Unicode LTR isolates (U+2066 … U+2069) so numbers and
/// codes keep their order inside RTL text (design §5.4, §8.5).
String ltrIsolate(String text) => '\u2066$text\u2069';
