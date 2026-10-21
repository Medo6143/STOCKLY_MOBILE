import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An adapter that answers every request in place of the network, or `null`
/// for Dio's own adapter to the real API. Tests (and a local tool) override
/// it; the app itself never sets one.
final httpAdapterOverrideProvider = Provider<HttpClientAdapter?>((ref) => null);
