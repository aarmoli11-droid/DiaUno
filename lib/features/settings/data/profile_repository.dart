import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.themeMode,
    required this.onboardingCompleted,
  });

  final String id;
  final String displayName;
  final String email;
  final String themeMode;
  final bool onboardingCompleted;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String,
    displayName: map['display_name'] as String,
    email: map['email'] as String,
    themeMode: map['theme_mode'] as String? ?? 'system',
    onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
  );
}

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  /// El perfil propio se lee por RPC: los correos no están expuestos como
  /// columna seleccionable por los clientes (sólo nombre, avatar e id).
  Future<UserProfile?> getProfile() async {
    final rows = await _client.rpc('get_my_profile');
    if (rows is! List || rows.isEmpty) return null;
    return UserProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> updateDisplayName(String name) async {
    await _client
        .from('profiles')
        .update({'display_name': name.trim()})
        .eq('id', _userId);
  }

  Future<void> completeOnboarding() async {
    await _client
        .from('profiles')
        .update({'onboarding_completed': true})
        .eq('id', _userId);
  }
}
