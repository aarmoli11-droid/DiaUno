import 'package:flutter_test/flutter_test.dart';
import 'package:diauno/core/utils/date_x.dart';
import 'package:diauno/features/tasks/domain/task.dart';
import 'package:diauno/features/tasks/domain/task_rules.dart';

void main() {
  group('generateOccurrences', () {
    test('una tarea sin repetición genera una sola fecha', () {
      final start = Date(2026, 1, 10);
      final dates = generateOccurrences(
        start: start,
        recurrence: Recurrence.none,
        interval: 3,
        until: Date(2026, 3, 10),
      );
      expect(dates, [start]);
    });

    test('respeta el intervalo semanal y la fecha de fin', () {
      final dates = generateOccurrences(
        start: Date(2026, 1, 5),
        recurrence: Recurrence.weekly,
        interval: 2,
        endDate: Date(2026, 1, 20),
        until: Date(2026, 3, 1),
      );
      expect(dates.map((d) => d.iso), ['2026-01-05', '2026-01-19']);
    });

    test('el monthly recorta los meses cortos', () {
      final dates = generateOccurrences(
        start: Date(2026, 1, 31),
        recurrence: Recurrence.monthly,
        interval: 1,
        until: Date(2026, 4, 30),
      );
      expect(dates.map((d) => d.iso), [
        '2026-01-31',
        '2026-02-28',
        '2026-03-28',
        '2026-04-28',
      ]);
    });

    test('never genera fechas posteriores a until', () {
      final dates = generateOccurrences(
        start: Date(2026, 1, 1),
        recurrence: Recurrence.daily,
        interval: 1,
        until: Date(2026, 1, 5),
      );
      expect(dates.length, 5);
      expect(dates.last.iso, '2026-01-05');
    });
  });
}
