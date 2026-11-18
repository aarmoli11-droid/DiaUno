import 'package:intl/intl.dart';

extension DateX on DateTime {
  String get yyyyMmDd => DateFormat('yyyy-MM-dd').format(this);
  String get shortDate => DateFormat('d MMM', 'es').format(this);
  String get longDate => DateFormat('EEEE, d MMMM y', 'es').format(this);
  String get time => DateFormat('HH:mm').format(this);
  DateTime get dateOnly => DateTime(year, month, day);
  DateTime addDays(int days) => DateTime(year, month, day + days);
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

DateTime parseDate(String value) =>
    DateTime.parse(value.length == 10 ? '${value}T00:00:00' : value);
DateTime? parseDateOrNull(String? value) =>
    value == null ? null : parseDate(value);
Date? tryParseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return Date.tryParse(value);
}

/// Fecha sin dependencias de zona horaria para cálculos de calendario.
class Date implements Comparable<Date> {
  const Date(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory Date.fromDateTime(DateTime dt) => Date(dt.year, dt.month, dt.day);
  factory Date.today() => Date.fromDateTime(DateTime.now());

  static Date? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return Date(y, m, d);
  }

  DateTime toDateTime() => DateTime(year, month, day);

  Date addDays(int days) =>
      Date.fromDateTime(toDateTime().add(Duration(days: days)));
  Date addMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    return Date(total ~/ 12, total % 12 + 1, day);
  }

  Date addWeeks(int weeks) => addDays(weeks * 7);

  int get weekday => toDateTime().weekday;
  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  String get shortDate => DateFormat('d MMM', 'es').format(toDateTime());
  String get longDate =>
      DateFormat('EEEE, d MMMM y', 'es').format(toDateTime());

  @override
  int compareTo(Date other) => iso.compareTo(other.iso);

  @override
  bool operator ==(Object other) =>
      other is Date &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}
