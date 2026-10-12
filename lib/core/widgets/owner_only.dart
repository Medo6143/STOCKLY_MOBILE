import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';

/// Renders [child] only for the shop's Owner (design §11). The server still
/// answers `403` if a Staff request gets through.
class OwnerOnly extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(isOwnerProvider) ? child : const SizedBox.shrink();
}
