import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/time/clock.dart';

/// The fake backend in builds made with `STOCKLY_BACKEND=fake`, else `null`.
/// [kFakeBackendEnabled] is a `const`, so real builds tree-shake the fake.
final fakeBackendProvider = Provider<FakeBackendAdapter?>((ref) {
  if (!kFakeBackendEnabled) {
    return null;
  }
  final clock = ref.watch(clockProvider);
  return FakeBackendAdapter(
    state: FakeSeed.pharmacy(clock.now()),
    config: const FakeBackendConfig(),
    clock: clock,
    uuid: ref.watch(uuidGeneratorProvider),
  );
});
