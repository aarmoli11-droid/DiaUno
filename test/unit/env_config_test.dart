import 'package:diauno/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env', () {
    test('acepta publishable key o anon key como clave efectiva', () {
      final expected = Env.supabaseUrl.isNotEmpty && Env.apiKey.isNotEmpty;
      expect(Env.isConfigured, expected);
      expect(Env.missingVariables.isEmpty, expected);
    });

    test('el mensaje nombra la variable de URL ausente', () {
      final message = Env.messageForMissing(['SUPABASE_URL']);
      expect(message, contains('SUPABASE_URL'));
      expect(message, contains('--dart-define-from-file=.env.local'));
    });

    test('el mensaje acepta cualquiera de las dos claves públicas', () {
      final message = Env.messageForMissing([
        'SUPABASE_PUBLISHABLE_KEY o SUPABASE_ANON_KEY',
      ]);
      expect(message, contains('SUPABASE_PUBLISHABLE_KEY'));
      expect(message, contains('SUPABASE_ANON_KEY'));
      expect(message, isNot(contains('service_role')));
    });

    test('sin variables ausentes no se muestra mensaje', () {
      expect(Env.messageForMissing(const []), isEmpty);
    });

    test('el mensaje de la app coincide con las variables ausentes', () {
      expect(
        Env.configurationMessage,
        Env.messageForMissing(Env.missingVariables),
      );
    });

    test('el callback de auth está registrado con el esquema de la app', () {
      expect(Env.authRedirectUrl, 'diauno://auth/recovery');
    });
  });
}
