import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/fake_backend/fake_backend_provider.dart';

/// An adapter that answers every request in place of the network, or `null`
/// for Dio's own adapter to the real API. Tests and local tools override
/// it; the app itself never sets one.
final httpAdapterOverrideProvider = Provider<HttpClientAdapter?>(
  (ref) => ref.watch(fakeBackendProvider),
);
