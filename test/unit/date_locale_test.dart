import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:diauno/core/utils/date_x.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  test('las fechas en espanol se formatean sin LocaleDataException', () {
    final date = Date(2026, 11, 24);
    final dateTime = DateTime(2026, 11, 24);

    expect(date.shortDate, contains('nov'));
    expect(date.longDate, contains('2026'));
    expect(dateTime.longDate, contains('2026'));
    expect(
      DateFormat('EEEE, d MMMM', 'es').format(dateTime),
      contains('noviembre'),
    );
  });

  test('main inicializa el locale de fechas antes de arrancar la app', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("initializeDateFormatting('es'"));
  });
}
