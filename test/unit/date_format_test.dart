import 'package:diauno/core/utils/date_x.dart';
import 'package:diauno/features/projects/domain/project.dart';
import 'package:diauno/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(initializeApp);

  test('Inicio y Agenda pueden formatear fechas después del arranque', () {
    final date = Date(2026, 11, 20);

    expect(date.shortDate, isNotEmpty);
    expect(date.longDate, contains('2026'));
    expect(date.toDateTime().time, matches(RegExp(r'^\d{2}:\d{2}$')));
  });

  test(
    'guardar un proyecto convierte sus fechas a ISO sin depender del locale',
    () {
      final project = Project(
        id: '',
        ownerId: '',
        name: 'Proyecto de prueba',
        description: '',
        colorHex: '#2E6B4E',
        iconName: 'folder',
        status: 'active',
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 12, 31),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      );

      final insert = project.toInsert('usuario-de-prueba');

      expect(insert['start_date'], '2026-11-20');
      expect(insert['end_date'], '2026-12-31');
    },
  );
}
