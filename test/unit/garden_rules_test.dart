import 'package:flutter_test/flutter_test.dart';
import 'package:diauno/features/garden/domain/garden.dart';

void main() {
  test('la flor es determinista para un mismo número de puntos', () {
    expect(GardenRules.flowerForPoints(0), 'sprout');
    expect(GardenRules.flowerForPoints(40), 'daisy');
    expect(GardenRules.flowerForPoints(120), 'tulip');
    expect(GardenRules.flowerForPoints(250), 'sunflower');
    expect(GardenRules.flowerForPoints(400), 'orchid');
  });

  test('la etapa del árbol sigue el progreso real', () {
    expect(GardenRules.treeStage(0), 0);
    expect(GardenRules.treeStage(24), 1);
    expect(GardenRules.treeStage(25), 2);
    expect(GardenRules.treeStage(55), 3);
    expect(GardenRules.treeStage(80), 4);
  });

  test('un evento personal sin proyecto no rompe la carga del jardín', () {
    final event = GardenEvent.fromMap({
      'id': 'evento-personal',
      'project_id': null,
      'points': 20,
      'flower_type': 'sprout',
      'event_type': 'task_completed',
      'created_at': '2026-11-20T19:30:43.729284Z',
      'projects': <dynamic>[],
    });

    expect(event.projectId, isNull);
    expect(event.projectName, isNull);
    expect(event.points, 20);
  });

  test(
    'un evento de tarea personal sin proyecto no rompe la serialización',
    () {
      // Fixture sintético con la forma que devolvía Supabase antes de la corrección.
      final event = GardenEvent.fromMap(const <String, dynamic>{
        'id': '00000000-0000-4000-8000-000000000001',
        'project_id': null,
        'points': 20,
        'flower_type': 'sprout',
        'event_type': 'task_completed',
        'created_at': '2026-01-01T10:00:00.000000+00:00',
        'projects': null,
      });

      expect(event.projectId, isNull);
      expect(event.projectName, isNull);
      expect(event.points, 20);
      expect(event.eventType, 'task_completed');
      expect(event.flowerType, 'sprout');
      expect(event.createdAt.year, 2026);
    },
  );

  test('lee el nombre del proyecto embebido como objeto de PostgREST', () {
    final event = GardenEvent.fromMap(<String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000002',
      'project_id': '00000000-0000-4000-8000-000000000003',
      'points': 20,
      'flower_type': 'daisy',
      'event_type': 'task_completed',
      'created_at': '2026-01-02T10:00:00.000000+00:00',
      'projects': <String, dynamic>{'name': 'Proyecto sintético'},
    });

    expect(event.projectId, '00000000-0000-4000-8000-000000000003');
    expect(event.projectName, 'Proyecto sintético');
  });

  test('acepta también el embed antiguo como lista', () {
    final event = GardenEvent.fromMap(<String, dynamic>{
      'id': '00000000-0000-4000-8000-000000000004',
      'project_id': '00000000-0000-4000-8000-000000000003',
      'points': 20,
      'flower_type': 'sprout',
      'event_type': 'task_completed',
      'created_at': '2026-01-03T10:00:00.000000+00:00',
      'projects': <dynamic>[
        <String, dynamic>{'name': 'Proyecto sintético'},
      ],
    });

    expect(event.projectName, 'Proyecto sintético');
  });

  test('un jardín vacío mantiene su estado inicial', () {
    const events = <GardenEvent>[];
    final total = events.fold<int>(0, (a, e) => a + e.points);

    expect(total, 0);
    expect(GardenRules.flowerForPoints(total), 'sprout');
    expect(GardenRules.treeStage(0), 0);
  });
}
