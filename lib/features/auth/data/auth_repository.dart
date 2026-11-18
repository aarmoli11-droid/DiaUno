import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/app_failure.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authState => _client.auth.onAuthStateChange;

  Future<User> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        throw const AuthFailure(
          'No pudimos iniciar sesión. Verifica tus datos.',
        );
      }
      return response.user!;
    } on AppFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e.message));
    } catch (_) {
      throw const NetworkFailure('No se pudo conectar. Revisa tu conexión.');
    }
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Env.authRedirectUrl,
        data: {'display_name': displayName.trim()},
      );
      return response.user;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e.message));
    } catch (_) {
      throw const NetworkFailure(
        'No se pudo crear la cuenta. Revisa tu conexión.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Cerrar sesión localmente nunca debe bloquear al usuario.
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: Env.authRedirectUrl,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e.message));
    } catch (_) {
      throw const NetworkFailure();
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyAuthMessage(e.message));
    }
  }

  /// Google OAuth requiere: habilitar el proveedor en Supabase Auth y registrar
  /// las URLs de callback por plataforma. No se activa sin ENABLE_GOOGLE_OAUTH.
  Future<Uri> googleAuthorizationUrl() async {
    final response = await _client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
    );
    return Uri.parse(response.url);
  }

  String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already exists')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (lower.contains('password should be')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirma tu correo antes de continuar.';
    }
    if (lower.contains('rate limit')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return message;
  }
}
