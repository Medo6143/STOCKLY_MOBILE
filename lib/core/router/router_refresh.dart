import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/splash/presentation/providers/splash_notifier.dart';

/// Tells go_router to run the redirect again whenever the auth state or the
/// splash timing gate changes, so the router is created only once.
final class RouterRefresh extends ChangeNotifier {
  new(Ref ref) {
    ref
      ..listen(authProvider, (_, _) => notifyListeners())
      ..listen(splashProvider, (_, _) => notifyListeners());
  }
}
