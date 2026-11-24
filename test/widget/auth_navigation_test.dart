import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diauno/core/data/local_store.dart';
import 'package:diauno/core/providers/core_providers.dart';
import 'package:diauno/core/router/app_router.dart';
import 'package:diauno/core/theme/app_theme.dart';
import 'package:diauno/features/auth/application/auth_controller.dart';
import 'package:diauno/features/auth/data/auth_repository.dart';
import 'package:diauno/features/home/application/home_controller.dart';

/// Repositorio falso: nunca toca la red. Mantiene coherentes el getter de
/// sesión que lee el router y el stream que alimenta los providers de Riverpod.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository()
    : _testSession = Session.fromJson({
        'access_token': 'test-access-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'test-refresh-token',
        'user': {
          'id': 'test-user-id',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'prueba@diauno.test',
          'user_metadata': {'display_name': 'Prueba'},
          'created_at': '2026-01-01T00:00:00Z',
        },
      })!,
      // El repo falso anula todos los miembros que usan el cliente. El
      // `autoRefreshToken: false` evita el temporizador periódico de GoTrue.
      super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Session _testSession;
  final StreamController<AuthState> _authController =
      StreamController<AuthState>.broadcast();

  Session? _session;
  Future<User> Function()? _signInOverride;
  Future<void> Function()? _signOutOverride;

  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int resetCalls = 0;
  int updateCalls = 0;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Stream<AuthState> get authState => _authController.stream;

  User get testUser => _testSession.user;

  void emit(AuthState state) => _authController.add(state);

  set signedIn(bool value) {
    _session = value ? _testSession : null;
    emit(
      AuthState(
        value ? AuthChangeEvent.signedIn : AuthChangeEvent.signedOut,
        _session,
      ),
    );
  }

  void holdSignInWith(Future<User> Function() callback) =>
      _signInOverride = callback;

  void holdSignOutWith(Future<void> Function() callback) =>
      _signOutOverride = callback;

  @override
  Future<User> signIn({required String email, required String password}) {
    signInCalls++;
    final override = _signInOverride;
    if (override != null) return override();
    signedIn = true;
    return Future.value(testUser);
  }

  @override
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    signUpCalls++;
    return testUser;
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    final override = _signOutOverride;
    if (override != null) return override();
    signedIn = false;
    return Future.value();
  }

  @override
  Future<void> resetPassword(String email) async {
    resetCalls++;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updateCalls++;
  }

  Future<void> dispose() => _authController.close();
}

class _Harness {
  _Harness(this.container, this.router, this.repo);

  final ProviderContainer container;
  final GoRouter router;
  final FakeAuthRepository repo;
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? repository,
}) async {
  final repo = repository ?? FakeAuthRepository();
  addTearDown(repo.dispose);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      connectivityProvider.overrideWith((ref) async* {
        yield true;
      }),
      localStoreProvider.overrideWith((ref) async => LocalStore()),
      homeDataProvider.overrideWith(
        (ref) async => HomeData(
          projects: const [],
          todayTasks: const [],
          upcomingTasks: const [],
          events: const [],
          upcomingPayments: const [],
          gardenEvents: const [],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Equivale a los `ref.watch` de DiaUnoApp: sin una suscripción real los
  // StreamProvider de Riverpod 3 permanecen en AsyncLoading y no propagan
  // eventos al router.
  addTearDown(container.listen(authEventProvider, (_, _) {}).close);
  addTearDown(container.listen(authSessionProvider, (_, _) {}).close);

  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  // Fuerza la suscripción del controlador sticky antes de emitir eventos.
  container.read(passwordRecoveryProvider);
  return _Harness(container, router, repo);
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String email = 'prueba@diauno.test',
  String password = 'clave123456',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  testWidgets('1. el botón Iniciar sesión abre el formulario de acceso', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/login');
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Olvidé mi contraseña'), findsOneWidget);
  });

  testWidgets('2. el botón Crear cuenta abre el formulario de registro', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    expect(find.text('Crear cuenta'), findsOneWidget);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/register');
    expect(find.text('Crea tu espacio'), findsOneWidget);
    expect(find.text('Nombre visible'), findsOneWidget);
  });

  testWidgets('3. desde el login se vuelve a la bienvenida', (tester) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/welcome');
    expect(
      find.text('Organiza tus proyectos, tu tiempo y tu día.'),
      findsOneWidget,
    );
  });

  testWidgets('4. desde el registro se vuelve a la bienvenida', (tester) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/welcome');
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('5. desde el login se abre el registro', (tester) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/register');
    expect(find.text('Crea tu espacio'), findsOneWidget);
  });

  testWidgets('6. desde el registro se abre el login', (tester) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/login');
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
  });

  testWidgets('7. los campos vacíos muestran validación y no envían', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Introduce un correo válido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    expect(h.repo.signInCalls, 0);
  });

  testWidgets('8. un correo sin formato válido bloquea el envío', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await _enterCredentials(tester, email: 'correo-sin-arroba');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Introduce un correo válido'), findsOneWidget);
    expect(h.repo.signInCalls, 0);
  });

  testWidgets('9. contraseñas distintas muestran el error en recuperación', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    h.repo.emit(const AuthState(AuthChangeEvent.passwordRecovery, null));
    await tester.pumpAndSettle();
    expect(h.router.state.uri.path, '/auth/new-password');

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'clave123456');
    await tester.enterText(fields.at(1), 'clave654321');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(h.repo.updateCalls, 0);
  });

  testWidgets('10. Olvidé mi contraseña abre el formulario de recuperación', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/reset');
    expect(find.text('Recuperar acceso'), findsOneWidget);
  });

  testWidgets(
    '11. el estado de carga deshabilita Continuar y evita duplicados',
    (tester) async {
      final completer = Completer<User>();
      final repo = FakeAuthRepository();
      repo.holdSignInWith(() async {
        await completer.future;
        repo.signedIn = true;
        return repo.testUser;
      });
      final h = await _pumpApp(tester, repository: repo);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await _enterCredentials(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(repo.signInCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(button);
      await tester.pump();
      expect(repo.signInCalls, 1);

      completer.complete(repo.testUser);
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, '/home');
    },
  );

  testWidgets('12. un inicio de sesión correcto lleva al inicio protegido', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await _enterCredentials(tester);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(h.repo.signInCalls, 1);
    expect(h.router.state.uri.path, '/home');
    expect(find.text('Hola, Prueba'), findsOneWidget);
  });

  testWidgets('13. cerrar sesión devuelve a una pantalla pública', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    h.repo.signedIn = true;
    await tester.pumpAndSettle();
    expect(h.router.state.uri.path, '/home');

    await h.container.read(authActionsProvider.notifier).signOut();
    await tester.pumpAndSettle();

    expect(h.repo.signOutCalls, 1);
    expect(h.router.state.uri.path, '/auth/welcome');
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('14. la recuperación conserva su ruta especial', (tester) async {
    final h = await _pumpApp(tester);
    h.repo.emit(const AuthState(AuthChangeEvent.passwordRecovery, null));
    await tester.pumpAndSettle();

    expect(h.router.state.uri.path, '/auth/new-password');
    expect(
      find.text(
        'El enlace de recuperación es válido. Elige una contraseña nueva.',
      ),
      findsOneWidget,
    );
    expect(find.text('Repite la contraseña'), findsOneWidget);

    // Un evento posterior de sesión no debe sacar al usuario del formulario.
    h.repo.signedIn = true;
    await tester.pumpAndSettle();
    expect(h.router.state.uri.path, '/auth/new-password');
  });
}
