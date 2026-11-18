import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diauno/core/brand.dart';
import 'package:diauno/core/theme/app_theme.dart';
import 'package:diauno/shared/widgets/async_view.dart';

void main() {
  testWidgets('EmptyState muestra título y mensaje', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.eco_outlined,
            title: 'Sin datos',
            message: 'Aún no hay elementos.',
          ),
        ),
      ),
    );

    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.text('Aún no hay elementos.'), findsOneWidget);
  });

  test('los temas y la marca están disponibles sin inicializar Supabase', () {
    expect(Brand.name, isNotEmpty);
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });
}
