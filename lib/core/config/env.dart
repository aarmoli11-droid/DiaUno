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

  /// Esquema registrado en AndroidManifest.xml e Info.plist y añadido a
  /// `additional_redirect_urls` en Supabase Auth.
  static const String authRedirectUrl = 'diauno://auth/recovery';

  /// Preferimos la clave publicable cuando está disponible; la anon legacy
  /// sigue siendo válida y se mantiene como compatibilidad.
  static String get apiKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

  /// Variables que faltan para poder inicializar Supabase.
  static List<String> get missingVariables {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (apiKey.isEmpty) {
      missing.add('SUPABASE_PUBLISHABLE_KEY o SUPABASE_ANON_KEY');
    }
    return missing;
  }

  static bool get isConfigured => missingVariables.isEmpty;

  /// Mensaje único y comprobable para la pantalla de configuración pendiente.
  static String messageForMissing(List<String> missing) {
    if (missing.isEmpty) return '';
    return 'Faltan las variables de Supabase: ${missing.join(', ')}. '
        'Ejecuta la app con --dart-define-from-file=.env.local (consulta README.md).';
  }

  static String get configurationMessage => messageForMissing(missingVariables);
}
