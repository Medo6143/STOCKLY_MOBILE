import 'package:flutter/widgets.dart';

/// Up to two initials of [name] for an avatar: the first letter of the
/// first two words. Latin letters are upper-cased. Arabic initials are
/// joined with a zero-width non-joiner so they show as separate letters
/// instead of joining into a word. Empty when [name] has no letters.
String initialsOf(String name) {
  final words = name
      .trim()
      .split(_spaces)
      .where((word) => word.isNotEmpty)
      .take(_maxInitials)
      .toList();
  final letters = [
    for (final word in words) word.characters.first.toUpperCase(),
  ].where(_letter.hasMatch).toList();
  final arabic = letters.any(_arabic.hasMatch);
  return letters.join(arabic ? _nonJoiner : '');
}

const int _maxInitials = 2;
const String _nonJoiner = '\u200C';
final RegExp _spaces = RegExp(r'\s+');
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _arabic = RegExp(r'\p{Script=Arabic}', unicode: true);
