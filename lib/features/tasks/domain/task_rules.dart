import '../../../core/utils/date_x.dart';
import 'task.dart';

/// Genera fechas de ocurrencias de forma determinista.
/// Cada ocurrencia es un registro independiente con su propio historial.
List<Date> generateOccurrences({
  required Date start,
  required Recurrence recurrence,
  required int interval,
  Date? endDate,
  required Date until,
}) {
  if (recurrence == Recurrence.none ||
      interval < 1 ||
      until.compareTo(start) < 0) {
    return [start];
  }
  final step = interval < 1 ? 1 : interval;
  final result = <Date>[];
  var current = start;
  var guard = 0;
  while (current.compareTo(until) <= 0 && guard++ < 1200) {
    if (endDate != null && current.compareTo(endDate) > 0) break;
    result.add(current);
    current = _advance(current, recurrence, step);
  }
  return result;
}

Date _advance(Date date, Recurrence recurrence, int step) {
  switch (recurrence) {
    case Recurrence.daily:
      return date.addDays(step);
    case Recurrence.weekly:
      return date.addWeeks(step);
    case Recurrence.monthly:
      final target = date.addMonths(step);
      final lastDay = DateTime(target.year, target.month + 1, 0).day;
      return Date(
        target.year,
        target.month,
        target.day > lastDay ? lastDay : target.day,
      );
    case Recurrence.none:
      return date;
  }
}

/// Próxima fecha tras una ocurrencia ya cumplida.
Date nextOccurrence(Date completed, Recurrence recurrence, int interval) =>
    _advance(completed, recurrence, interval < 1 ? 1 : interval);
