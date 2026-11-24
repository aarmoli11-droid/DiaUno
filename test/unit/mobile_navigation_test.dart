import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diauno/core/data/local_store.dart';
import 'package:diauno/core/providers/core_providers.dart';
import 'package:diauno/shared/widgets/app_shell.dart';

const _branchPaths = ['/home', '/projects', '/agenda', '/shared', '/garden'];
const _secondaryPaths = ['/search', '/time', '/notifications', '/settings'];

class _MemoryStore extends LocalStore {
  @override
  Future<void> init() async {}

  @override
  void close() {}
}

class _TestScreen extends StatefulWidget {
  const _TestScreen(this.slug);

  final String slug;

  @override
  State<_TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<_TestScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.slug)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PANTALLA_${widget.slug.toUpperCase()}'),
          FilledButton(
            onPressed: () => setState(() => _count++),
            child: Text('Contador $_count'),
          ),
        ],
      ),
    ),
  );
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        for (final path in _branchPaths)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (context, state) => _TestScreen(path.substring(1)),
              ),
            ],
          ),
      ],
    ),
    for (final path in _secondaryPaths)
      GoRoute(
        path: path,
        builder: (context, state) => _TestScreen(path.substring(1)),
      ),
  ],
);

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWith((ref) async => _MemoryStore()),
        isOnlineProvider.overrideWithValue(true),
      ],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('Menú'));
  await tester.pumpAndSettle();
  expect(find.byType(Drawer), findsOneWidget);
}

void main() {
  testWidgets('a 390 px la barra inferior tiene cinco elementos y Agenda no', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));

    for (final label in [
      'Inicio',
      'Proyectos',
      'Compartidos',
      'Jardín',
      'Menú',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'Falta $label');
    }
    expect(find.text('Agenda'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Navegación principal',
      ),
      findsOneWidget,
    );
  });

  testWidgets('los cuatro destinos principales activan sus ramas', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));

    const cases = {
      'Inicio': 'home',
      'Proyectos': 'projects',
      'Compartidos': 'shared',
      'Jardín': 'garden',
    };
    for (final entry in cases.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(
        find.text('PANTALLA_${entry.value.toUpperCase()}'),
        findsOneWidget,
        reason: '${entry.key} no abrió su rama',
      );
      expect(find.byType(Drawer), findsNothing);
    }
  });

  testWidgets('Menú abre el Drawer con las cinco opciones y la X lo cierra', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));
    await _openDrawer(tester);

    for (final label in [
      'Agenda',
      'Buscar',
      'Tiempo',
      'Notificaciones',
      'Configuración',
    ]) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: 'Falta $label en el Drawer',
      );
    }
    expect(find.text('Claro'), findsNothing);
    expect(find.text('Oscuro'), findsNothing);

    await tester.tap(find.byTooltip('Cerrar menú'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('pulsar fuera y el botón Atrás cierran el Drawer', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));

    await _openDrawer(tester);
    await tester.tapAt(const Offset(370, 400));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('PANTALLA_HOME'), findsOneWidget);

    await _openDrawer(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('PANTALLA_HOME'), findsOneWidget);
  });

  testWidgets('Agenda desde el Drawer activa su rama y marca Menú', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));
    await _openDrawer(tester);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.text('PANTALLA_AGENDA'), findsOneWidget);
    expect(find.text('Agenda'), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Menú' &&
            w.properties.selected == true,
      ),
      findsOneWidget,
    );

    // El Drawer sigue disponible mientras la rama de Agenda está activa.
    await _openDrawer(tester);
    await tester.tap(find.byTooltip('Cerrar menú'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA_AGENDA'), findsOneWidget);
  });

  testWidgets('las opciones secundarias abren su ruta sin apilar duplicados', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));

    const cases = {
      'Buscar': 'search',
      'Tiempo': 'time',
      'Notificaciones': 'notifications',
      'Configuración': 'settings',
    };
    for (final entry in cases.entries) {
      await _openDrawer(tester);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(
        find.text('PANTALLA_${entry.value.toUpperCase()}'),
        findsOneWidget,
        reason: '${entry.key} no abrió su ruta',
      );
      expect(find.byType(Drawer), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA_HOME'), findsOneWidget);
    }
  });

  testWidgets('el estado de las ramas se conserva al cambiar de destino', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));

    await tester.tap(find.text('Contador 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proyectos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Contador 1'), findsOneWidget);

    await _openDrawer(tester);
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contador 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await _openDrawer(tester);
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Contador 1'), findsOneWidget);
  });

  testWidgets('a 1200 px permanece el sidebar y no aparece Menú', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1200, 800));

    for (final label in [
      'Inicio',
      'Proyectos',
      'Agenda',
      'Compartidos',
      'Jardín',
      'Buscar',
      'Tiempo',
      'Notificaciones',
      'Ajustes',
    ]) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: 'Falta $label en el sidebar',
      );
    }
    expect(find.text('Menú'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Navegación principal',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA_AGENDA'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });
}
