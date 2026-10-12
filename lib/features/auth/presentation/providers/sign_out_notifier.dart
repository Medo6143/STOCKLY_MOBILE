import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_state.dart';

final class SignOutNotifier extends Notifier<SignOutState> {
  @override
  SignOutState build() => const SignOutState();

  Future<void> signOut() async {
    if (state.inProgress) {
      return;
    }
    state = const SignOutState(inProgress: true);
    await ref.read(authProvider.notifier).logout();
    if (ref.mounted) {
      state = const SignOutState();
    }
  }
}

final NotifierProvider<SignOutNotifier, SignOutState> signOutProvider =
    NotifierProvider.autoDispose<SignOutNotifier, SignOutState>(
      SignOutNotifier.new,
    );
