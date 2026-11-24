import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diauno/core/providers/core_providers.dart';
import 'package:diauno/core/router/app_router.dart';

class _RouterHarness extends ConsumerWidget {
  const _RouterHarness({this.onRouter});

  final ValueChanged<GoRouter>? onRouter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    onRouter?.call(router);
    return MaterialApp.router(routerConfig: router);
  }
}

void main() {
  late SupabaseClient client;

  setUp(() {
    // Cliente local sin red: solo se usa para resolver el provider del router.
    client = SupabaseClient(
      'https://example.supabase.co',
      'clave-publica-de-prueba',
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  Future<GoRouter?> pumpRouter(
    WidgetTester tester, {
    ValueChanged<GoRouter>? onRouter,
  }) async {
    GoRouter? router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supabaseProvider.overrideWithValue(client)],
        child: _RouterHarness(
          onRouter: (value) {
            router = value;
            onRouter?.call(value);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Crear cuenta abre el formulario de registro', (tester) async {
    await pumpRouter(tester);

    expect(find.text('Crear cuenta'), findsOneWidget);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu espacio'), findsOneWidget);
    expect(find.text('Nombre visible'), findsOneWidget);
  });

  testWidgets('Iniciar sesión abre el formulario de acceso', (tester) async {
    await pumpRouter(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('el formulario muestra errores de validación', (tester) async {
    await pumpRouter(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('Escribe tu nombre'), findsOneWidget);
    expect(find.text('Introduce un correo válido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
  });

  testWidgets('un usuario sin sesión no entra a rutas privadas', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    expect(router, isNotNull);

    router!.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Hola'), findsNothing);
  });

  group('redirecciones de autenticación', () {
    test('la guardia protege el área privada sin bloquear el registro', () {
      expect(
        authGuardRedirect(location: '/home', loggedIn: false),
        '/auth/welcome',
      );
      expect(
        authGuardRedirect(location: '/auth/register', loggedIn: false),
        isNull,
      );
      expect(
        authGuardRedirect(location: '/auth/login', loggedIn: false),
        isNull,
      );
      expect(
        authGuardRedirect(location: '/auth/welcome', loggedIn: true),
        '/home',
      );
    });

    test('la ruta contenedora /auth no captura sus rutas hijas', () {
      expect(authShellRedirect('/auth'), '/auth/welcome');
      expect(authShellRedirect('/auth/login'), isNull);
      expect(authShellRedirect('/auth/register'), isNull);
      expect(authShellRedirect('/auth/reset'), isNull);
      expect(authShellRedirect('/auth/welcome'), isNull);
    });
  });
}
