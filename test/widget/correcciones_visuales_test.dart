import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diauno/core/theme/app_theme.dart';
import 'package:diauno/core/theme/tokens.dart';
import 'package:diauno/features/agenda/presentation/agenda_screen.dart';
import 'package:diauno/features/garden/presentation/garden_screen.dart';
import 'package:diauno/features/notifications/presentation/notifications_screen.dart';
import 'package:diauno/features/projects/application/projects_controller.dart';
import 'package:diauno/features/projects/domain/project.dart';
import 'package:diauno/features/projects/presentation/projects_screens.dart';
import 'package:diauno/features/tasks/application/tasks_controller.dart';
import 'package:diauno/features/tasks/domain/task.dart';
import 'package:diauno/features/tasks/presentation/task_screens.dart';

class _FakeTaskActions extends TaskActions {
  _FakeTaskActions(this.created);

  final List<TaskItem> created;

  @override
  Future<TaskItem> create(TaskItem task) async {
    created.add(task);
    return task;
  }

  @override
  Future<String> currentUserId() async => 'test-user';
}

Widget _titleApp(ThemeData theme) => MaterialApp(
  theme: theme,
  home: const Scaffold(
    body: Column(
      children: [
        ProjectDialogTitle(text: 'Nuevo proyecto'),
        ProjectDialogTitle(text: 'Editar proyecto'),
      ],
    ),
  ),
);

Widget _notificationsApp(ThemeData theme) =>
    MaterialApp(theme: theme, home: const NotificationsScreen());

Finder _gardenPainter() => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint &&
      widget.painter?.runtimeType.toString() == '_GardenPainter',
);

void main() {
  group('títulos de Crear/Editar proyecto', () {
    testWidgets('usan el color semántico en modo claro', (tester) async {
      await tester.pumpWidget(_titleApp(AppTheme.light()));
      final esperado = AppTheme.light().colorScheme.onSurface;
      for (final titulo in ['Nuevo proyecto', 'Editar proyecto']) {
        final text = tester.widget<Text>(find.text(titulo));
        expect(text.style?.color, esperado);
      }
    });

    testWidgets('usan el color semántico en modo oscuro', (tester) async {
      await tester.pumpWidget(_titleApp(AppTheme.dark()));
      final esperado = AppTheme.dark().colorScheme.onSurface;
      for (final titulo in ['Nuevo proyecto', 'Editar proyecto']) {
        final text = tester.widget<Text>(find.text(titulo));
        expect(text.style?.color, esperado);
      }
    });

    testWidgets('cambian de tema sin reiniciar la aplicación', (tester) async {
      await tester.pumpWidget(_titleApp(AppTheme.light()));
      expect(
        tester.widget<Text>(find.text('Nuevo proyecto')).style?.color,
        AppTheme.light().colorScheme.onSurface,
      );
      await tester.pumpWidget(_titleApp(AppTheme.dark()));
      await tester.pumpAndSettle();
      for (final titulo in ['Nuevo proyecto', 'Editar proyecto']) {
        expect(
          tester.widget<Text>(find.text(titulo)).style?.color,
          AppTheme.dark().colorScheme.onSurface,
        );
      }
    });

    testWidgets('conservan la tipografía headlineSmall del tema', (
      tester,
    ) async {
      await tester.pumpWidget(_titleApp(AppTheme.light()));
      final context = tester.element(find.byType(ProjectDialogTitle).first);
      final base = Theme.of(context).textTheme.headlineSmall!;
      final text = tester.widget<Text>(find.text('Nuevo proyecto'));
      expect(text.style?.fontFamily, base.fontFamily);
      expect(text.style?.fontWeight, base.fontWeight);
      expect(text.style?.letterSpacing, base.letterSpacing);
      expect(text.textAlign, isNull);
    });

    test('ambos diálogos usan el título semántico', () {
      final source = File(
        'lib/features/projects/presentation/projects_screens.dart',
      ).readAsStringSync();
      expect(source, contains("ProjectDialogTitle(text: 'Nuevo proyecto')"));
      expect(source, contains("ProjectDialogTitle(text: 'Editar proyecto')"));
      expect(source, isNot(contains("Text('Nuevo proyecto')")));
      expect(source, isNot(contains("Text('Editar proyecto')")));
    });
  });

  group('bordes del jardín', () {
    testWidgets('el dibujo se recorta con el mismo radio del contenedor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: GardenCanvas(points: 80)),
        ),
      );
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(AppRadius.lg));
      expect(_gardenPainter(), findsOneWidget);
    });

    testWidgets('los gestos siguen funcionando y los puntos no cambian', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: GardenCanvas(points: 80)),
        ),
      );
      final finder = _gardenPainter();
      final painter = tester.widget<CustomPaint>(finder).painter! as dynamic;
      expect(painter.points, 80);

      final center = tester.getCenter(finder);
      final size = tester.getSize(finder);
      await tester.tapAt(center + Offset(size.width * 0.3, 0));
      await tester.pump();
      expect(find.textContaining('80 puntos reales.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('notificaciones', () {
    testWidgets('muestra el estado no disponible en claro y oscuro', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(_notificationsApp(theme));
        await tester.pumpAndSettle();
        expect(find.text('Notificaciones no disponibles'), findsOneWidget);
        expect(
          find.text('Esta función todavía no está disponible en DíaUno.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
        final titulo = tester
            .widget<Text>(find.text('Notificaciones no disponibles'))
            .style!
            .color;
        final descripcion = tester
            .widget<Text>(
              find.text('Esta función todavía no está disponible en DíaUno.'),
            )
            .style!
            .color;
        final p = theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        expect(titulo, p.text);
        expect(descripcion, p.textSecondary);
        expect(find.text('Marcar todas'), findsNothing);
      }
    });

    testWidgets('respeta el cambio de tema sin reiniciar', (tester) async {
      await tester.pumpWidget(_notificationsApp(AppTheme.light()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_notificationsApp(AppTheme.dark()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.text('Notificaciones no disponibles'))
            .style!
            .color,
        AppColors.dark.text,
      );
    });

    test('la ruta y el acceso del Drawer se conservan', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/notifications'"));
      expect(router, contains('NotificationsScreen'));
      final nav = File(
        'test/unit/mobile_navigation_test.dart',
      ).readAsStringSync();
      expect(nav, contains("'/notifications'"));
      expect(nav, contains('Notificaciones'));
    });
  });

  group('botón central de Agenda', () {
    testWidgets('abre el formulario de tareas y permite guardar', (
      tester,
    ) async {
      final created = <TaskItem>[];
      final router = GoRouter(
        initialLocation: '/agenda',
        routes: [
          GoRoute(
            path: '/agenda',
            builder: (_, _) => Scaffold(
              body: Center(
                child: AgendaQuickAddTaskButton(
                  date: DateTime(2026, 11, 24),
                  compact: true,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/tasks/new',
            builder: (context, state) =>
                TaskFormScreen(dueDate: state.uri.queryParameters['date']),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskActionsProvider.overrideWith(() => _FakeTaskActions(created)),
            projectsProvider.overrideWith((ref) async => <Project>[]),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AgendaQuickAddTaskButton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byType(AgendaQuickAddTaskButton));
      await tester.pumpAndSettle();
      expect(find.byType(TaskFormScreen), findsOneWidget);
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(find.text('2026-11-24'), findsOneWidget);
      expect(find.text('Guardar tarea'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Tarea de prueba',
      );
      await tester.ensureVisible(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar tarea'));
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(created.single.title, 'Tarea de prueba');
      expect(created.single.startDate.iso, '2026-11-24');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    test('el botón inferior conserva su flujo original', () {
      final source = File(
        'lib/features/agenda/presentation/agenda_screen.dart',
      ).readAsStringSync();
      expect(source, contains('floatingActionButton: FloatingActionButton('));
      expect(
        source,
        contains(
          "context.push('/tasks/new?date=\${Date.fromDateTime(_selected).iso}')",
        ),
      );
      expect(source, isNot(contains("context.push('/agenda/events/new')")));
    });
  });
}
