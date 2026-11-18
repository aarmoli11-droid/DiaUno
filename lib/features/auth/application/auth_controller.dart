import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

final authSessionProvider = StreamProvider((ref) {
  return ref
      .watch(authRepositoryProvider)
      .authState
      .map((state) => state.session);
});

final currentUserProvider = Provider((ref) {
  final session = ref.watch(authSessionProvider).value;
  return session?.user ?? ref.read(supabaseProvider).auth.currentUser;
});

final authActionsProvider = NotifierProvider<AuthActions, bool>(
  AuthActions.new,
);

class AuthActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> signIn({required String email, required String password}) async {
    state = true;
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
    } finally {
      state = false;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = true;
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, displayName: displayName);
    } finally {
      state = false;
    }
  }

  Future<void> resetPassword(String email) async {
    state = true;
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
    } finally {
      state = false;
    }
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}
