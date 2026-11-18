/// Configuración inyectada en tiempo de compilación.
///
/// Ejecutar con:
/// flutter run --dart-define-from-file=.env.local
/// Los valores sensibles nunca se versionan; .env.local está en .gitignore.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String projectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
  );

  /// Google OAuth necesita configuración externa (proveedor en Supabase +
  /// esquema de callback por plataforma). No se activa por defecto.
  static const bool enableGoogleOAuth = bool.fromEnvironment(
    'ENABLE_GOOGLE_OAUTH',
    defaultValue: false,
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Preferimos la clave publicable cuando está disponible; la anon legacy
  /// sigue siendo válida y se mantiene como compatibilidad.
  static String get apiKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;
}
