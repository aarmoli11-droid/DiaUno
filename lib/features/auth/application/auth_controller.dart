import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Evento crudo de Supabase Auth. Necesario para distinguir una sesión normal
/// de una sesión de recuperación de contraseña.
final authEventProvider = StreamProvider<AuthChangeEvent>((ref) {
  return ref
      .watch(authRepositoryProvider)
      .authState
      .map((state) => state.event);
});

/// `true` mientras la app esté procesando un enlace `recovery`.
///
/// El SDK emite `passwordRecovery` una sola vez al detectar el deep link. Ese
/// estado debe conservarse hasta que la contraseña se haya actualizado: si se
/// leyera sólo el último evento, un `signedIn`/`tokenRefreshed` posterior
/// provocaría un bucle entre `/auth/new-password` y `/auth/welcome`.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryController, bool>(
      PasswordRecoveryController.new,
    );

class PasswordRecoveryController extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authEventProvider, (_, next) {
      final event = next.value;
      if (event == AuthChangeEvent.passwordRecovery) {
        state = true;
      } else if (event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.signedOut) {
        state = false;
      }
    }, fireImmediately: true);
    return false;
  }
}

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

  /// Completa el flujo de recuperación: guarda la contraseña y cierra la sesión
  /// temporal para que el usuario vuelva al login con la nueva clave.
  Future<void> updatePassword(String newPassword) async {
    state = true;
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      await ref.read(authRepositoryProvider).signOut();
    } finally {
      state = false;
    }
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}
