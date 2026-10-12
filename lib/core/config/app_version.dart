/// The app version shown in settings. Kept equal to `version:` in
/// `pubspec.yaml` by a test, so no platform package is needed to read it.
abstract final class AppVersion {
  static const String name = '1.0.0';
  static const int build = 1;

  /// `1.0.0 (1)`.
  static String get display => '$name ($build)';
}
