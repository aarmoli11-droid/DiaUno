import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diauno/core/data/local_store.dart';
import 'package:diauno/core/providers/core_providers.dart';
import 'package:diauno/core/router/app_router.dart';
import 'package:diauno/core/theme/app_theme.dart';
import 'package:diauno/core/theme/tokens.dart';
import 'package:diauno/features/auth/application/auth_controller.dart';
import 'package:diauno/features/auth/data/auth_repository.dart';
import 'package:diauno/features/home/application/home_controller.dart';
import 'package:diauno/features/projects/application/projects_controller.dart';
import 'package:diauno/features/projects/data/projects_repository.dart';
import 'package:diauno/features/projects/domain/project.dart';
import 'package:diauno/features/settings/application/settings_controller.dart';
import 'package:diauno/features/settings/data/profile_repository.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : _session = Session.fromJson({
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
      super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Session _session;
  final StreamController<AuthState> _events =
      StreamController<AuthState>.broadcast();

  int signOutCalls = 0;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session.user;

  @override
  Stream<AuthState> get authState => _events.stream;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  Future<void> dispose() => _events.close();
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<UserProfile?> getProfile() async => null;
}

class _FailingProjectsRepository extends ProjectsRepository {
  _FailingProjectsRepository()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<Project> createProject(Project project) async {
    throw Exception(
      'PostgrestException(message: Cannot coerce the result to a single JSON '
      'object, code: PGRST116)',
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeAuthRepository auth,
  bool online = true,
  List<Project>? projects,
  ProjectsRepository? projectsRepository,
}) async {
  addTearDown(auth.dispose);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
      profileProvider.overrideWith((ref) async {
        return const UserProfile(
          id: 'test-user-id',
          displayName: 'Prueba',
          email: 'prueba@diauno.test',
          themeMode: 'system',
          onboardingCompleted: true,
        );
      }),
      connectivityProvider.overrideWith((ref) async* {
        yield online;
      }),
      localStoreProvider.overrideWith((ref) async => LocalStore()),
      homeDataProvider.overrideWith((ref) async {
        return const HomeData(
          projects: [],
          todayTasks: [],
          upcomingTasks: [],
          events: [],
          upcomingPayments: [],
          gardenEvents: [],
        );
      }),
      if (projects != null)
        projectsProvider.overrideWith((ref) async => projects),
      if (projectsRepository != null)
        projectsRepositoryProvider.overrideWithValue(projectsRepository),
    ],
  );
  addTearDown(container.dispose);
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
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await initializeDateFormatting('es', null);
  });

  // Cada prueba fija su propio tamaño: `tester.view` expone los setters.
  void setMobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
    });
  }

  testWidgets('la barra transparente conserva iconos y texto coloreados', (
    tester,
  ) async {
    setMobileSize(tester);
    await _pumpApp(tester, auth: _FakeAuthRepository());

    final p = AppColors.light;
    final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
    expect(icon.color, p.navSelected);
    expect(icon.color, isNot(Colors.transparent));

    final label = tester.widget<Text>(find.text('Inicio'));
    expect(label.style?.color, p.navSelected);

    final inactive = tester.widget<Text>(find.text('Jardín'));
    expect(inactive.style?.color, p.navInactive);
  });

  testWidgets('la barra móvil es compacta y Agenda/Perfil van en el cajón', (
    tester,
  ) async {
    setMobileSize(tester);
    await _pumpApp(tester, auth: _FakeAuthRepository());

    final bar = tester.widget<SizedBox>(
      find.byKey(const Key('mobile-nav-bar')),
    );
    expect(bar.height, 56);
    final navBar = find.byKey(const Key('mobile-nav-bar'));
    expect(
      find.descendant(of: navBar, matching: find.text('Agenda')),
      findsNothing,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Perfil')),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();

    final drawerAgenda = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Agenda'),
    );
    final drawerProfile = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Perfil'),
    );
    expect(drawerAgenda, findsOneWidget);
    expect(drawerProfile, findsOneWidget);

    await tester.tap(drawerAgenda);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: navBar, matching: find.text('Agenda')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el scroll usa física de recorte y no estira la pantalla', (
    tester,
  ) async {
    setMobileSize(tester);
    await _pumpApp(tester, auth: _FakeAuthRepository());

    final context = tester.element(find.byType(MaterialApp));
    final physics = ScrollConfiguration.of(context).getScrollPhysics(context);
    expect(physics, isA<ClampingScrollPhysics>());
  });

  testWidgets('el perfil móvil permite cambiar el tema y cerrar sesión', (
    tester,
  ) async {
    setMobileSize(tester);
    final auth = _FakeAuthRepository();
    await _pumpApp(tester, auth: auth);

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Perfil')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
  });

  testWidgets('el aviso de sincronización no desborda en móvil', (
    tester,
  ) async {
    setMobileSize(tester);
    await _pumpApp(tester, auth: _FakeAuthRepository(), online: false);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('proyectos no desborda con tarjeta y aviso en móvil', (
    tester,
  ) async {
    setMobileSize(tester);
    final project = Project(
      id: 'project-1',
      ownerId: 'test-user-id',
      name: 'Proyecto con un nombre deliberadamente largo para móvil',
      description:
          'Descripción extensa que debe recortarse sin estirar la tarjeta.',
      colorHex: '#2E6B4E',
      iconName: 'folder',
      status: 'active',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      progressPercent: 42,
      gardenPoints: 8,
      totalTasks: 7,
      completedTasks: 3,
      myRole: ProjectRole.owner,
    );
    await _pumpApp(
      tester,
      auth: _FakeAuthRepository(),
      online: false,
      projects: [project],
    );

    await tester.tap(find.text('Proyectos').last);
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text(project.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crear proyecto no muestra el error crudo de PostgREST', (
    tester,
  ) async {
    setMobileSize(tester);
    await _pumpApp(
      tester,
      auth: _FakeAuthRepository(),
      projectsRepository: _FailingProjectsRepository(),
    );

    await tester.tap(find.text('Proyectos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nuevo proyecto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Proyecto con ñ');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Descripción con ñ y acentos',
    );
    expect(find.text('Proyecto con ñ'), findsOneWidget);
    expect(find.text('Descripción con ñ y acentos'), findsOneWidget);
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PostgrestException'), findsNothing);
    expect(find.textContaining('PGRST116'), findsNothing);
    expect(
      find.text('No se pudo completar la operación. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });
}
