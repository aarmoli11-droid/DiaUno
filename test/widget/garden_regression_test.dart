import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:diauno/features/garden/application/garden_controller.dart';
import 'package:diauno/features/garden/domain/garden.dart';
import 'package:diauno/features/garden/presentation/garden_screen.dart';
import 'package:diauno/features/projects/application/projects_controller.dart';
import 'package:diauno/features/projects/domain/project.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await initializeDateFormatting('es', null);
  });

  testWidgets('el jardín muestra la vista previa con eventos personales', (
    tester,
  ) async {
    final event = GardenEvent(
      id: 'evento-personal',
      projectId: null,
      points: 20,
      flowerType: 'sprout',
      eventType: 'task_completed',
      createdAt: DateTime.parse('2026-11-20T19:30:43.729284Z'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gardenEventsProvider(null).overrideWith((ref) async => [event]),
          projectsProvider.overrideWith((ref) async => <Project>[]),
        ],
        child: const MaterialApp(home: GardenScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('20 puntos acumulados'), findsOneWidget);
    expect(find.text('Aún no hay eventos.'), findsNothing);
  });
}
