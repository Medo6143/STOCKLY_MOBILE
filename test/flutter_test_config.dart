import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled brand fonts once, so widget tests render with the real
/// families (design §13.2).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  await testMain();
}

const Map<String, List<String>> _fonts = {
  'ReadexPro': [
    'assets/fonts/readex_pro/ReadexPro-Regular.ttf',
    'assets/fonts/readex_pro/ReadexPro-SemiBold.ttf',
    'assets/fonts/readex_pro/ReadexPro-Bold.ttf',
  ],
  'IBMPlexSansArabic': [
    'assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/ibm_plex_sans_arabic/IBMPlexSansArabic-SemiBold.ttf',
  ],
  'IBMPlexMono': [
    'assets/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf',
    'assets/fonts/ibm_plex_mono/IBMPlexMono-Medium.ttf',
  ],
};

Future<void> loadAppFonts() async {
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File(file).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
