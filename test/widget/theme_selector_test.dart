import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diauno/core/data/local_store.dart';
import 'package:diauno/core/providers/core_providers.dart';
import 'package:diauno/core/theme/app_theme.dart';
import 'package:diauno/features/auth/application/auth_controller.dart';
import 'package:diauno/features/settings/application/settings_controller.dart';
import 'package:diauno/features/settings/data/profile_repository.dart';
import 'package:diauno/features/settings/presentation/settings_screen.dart';

class _MemoryStore extends LocalStore {
  final Map<String, String> prefs = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? readPref(String key) => prefs[key];

  @override
  Future<void> writePref(String key, String value) async => prefs[key] = value;

  @override
  void close() {}
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository()
    : super(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<UserProfile?> getProfile() async => null;
}

class _SettingsHarness extends ConsumerWidget {
  const _SettingsHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const Scaffold(body: SettingsScreen()),
    );
  }
}

Widget _app(_MemoryStore store) => ProviderScope(
  overrides: [
    localStoreProvider.overrideWith((ref) async => store),
    profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    profileProvider.overrideWith((ref) async => null),
    currentUserProvider.overrideWithValue(null),
  ],
  child: const _SettingsHarness(),
);

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
  });
}

Future<void> _pump(WidgetTester tester, _MemoryStore store) async {
  // Desmonta el scope anterior para que cada caso tenga su propio contenedor.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
}

void main() {
  group('selector de tema en Ajustes', () {
    testWidgets('cabe en una línea y reparte segmentos iguales a todos los '
        'anchos', (tester) async {
      for (final width in [320.0, 360.0, 390.0, 768.0, 1200.0]) {
        _setWidth(tester, width);
        await _pump(tester, _MemoryStore());

        final selector = find.byType(SegmentedButton<ThemeMode>);
        expect(selector, findsOneWidget, reason: 'ancho $width');
        final button = tester.widget<SegmentedButton<ThemeMode>>(selector);
        expect(button.expandedInsets, EdgeInsets.zero);
        expect(button.showSelectedIcon, isFalse);

        final segments = find.descendant(
          of: selector,
          matching: find.byType(TextButton),
        );
        expect(segments, findsNWidgets(3));
        final widths = [
          for (var i = 0; i < 3; i++) tester.getSize(segments.at(i)).width,
        ];
        expect(widths[1], closeTo(widths[0], 1.0), reason: 'ancho $width');
        expect(widths[2], closeTo(widths[0], 1.0), reason: 'ancho $width');

        final labels = ['Sistema', 'Claro', 'Oscuro'];
        final icons = [
          Icons.brightness_auto,
          Icons.light_mode,
          Icons.dark_mode,
        ];
        for (var i = 0; i < labels.length; i++) {
          final label = find.text(labels[i]);
          expect(label, findsOneWidget, reason: 'ancho $width');
          expect(tester.widget<Text>(label).maxLines, 1);
          expect(tester.getSize(label).height, lessThan(24));

          final labelRect = tester.getRect(label);
          final segmentRect = tester.getRect(segments.at(i));
          expect(
            labelRect.left,
            greaterThanOrEqualTo(segmentRect.left - 1),
            reason: 'ancho $width / ${labels[i]}',
          );
          expect(
            labelRect.right,
            lessThanOrEqualTo(segmentRect.right + 1),
            reason: 'ancho $width / ${labels[i]}',
          );
        }
        for (final icon in icons) {
          expect(find.byIcon(icon), findsOneWidget, reason: 'ancho $width');
        }
      }
    });

    testWidgets(
      'las tres opciones se seleccionan, persisten, siguen al dispositivo '
      'y cambian el tema sin reiniciar',
      (tester) async {
        _setWidth(tester, 390);
        final store = _MemoryStore();
        await _pump(tester, store);

        final selector = find.byType(SegmentedButton<ThemeMode>);
        ThemeMode selected() =>
            tester.widget<SegmentedButton<ThemeMode>>(selector).selected.single;
        Brightness brightness() =>
            Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

        expect(selected(), ThemeMode.system);
        expect(store.prefs['theme_mode'], isNull);

        await tester.tap(find.text('Claro'));
        await tester.pumpAndSettle();
        expect(selected(), ThemeMode.light);
        expect(store.prefs['theme_mode'], 'light');
        expect(brightness(), Brightness.light);

        await tester.tap(find.text('Oscuro'));
        await tester.pumpAndSettle();
        expect(selected(), ThemeMode.dark);
        expect(store.prefs['theme_mode'], 'dark');
        expect(brightness(), Brightness.dark);

        await tester.tap(find.text('Sistema'));
        await tester.pumpAndSettle();
        expect(selected(), ThemeMode.system);
        expect(store.prefs['theme_mode'], 'system');
        expect(brightness(), Brightness.light);

        // «Sistema» debe reflejar el brillo real del dispositivo, no un valor fijo.
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(selected(), ThemeMode.system);
        expect(brightness(), Brightness.dark);
      },
    );

    testWidgets('el indicador de selección funciona en claro y oscuro', (
      tester,
    ) async {
      for (final entry in {
        ThemeMode.light: 'light',
        ThemeMode.dark: 'dark',
      }.entries) {
        _setWidth(tester, 390);
        final store = _MemoryStore()..prefs['theme_mode'] = entry.value;
        await _pump(tester, store);

        final selector = find.byType(SegmentedButton<ThemeMode>);
        expect(tester.widget<SegmentedButton<ThemeMode>>(selector).selected, {
          entry.key,
        });
        final label = entry.key == ThemeMode.light ? 'Claro' : 'Oscuro';
        expect(
          find.ancestor(of: find.text(label), matching: find.byType(Semantics)),
          findsWidgets,
        );
        expect(
          Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
          entry.key == ThemeMode.light ? Brightness.light : Brightness.dark,
        );
      }
    });

    test(
      'mantiene iconos y evita el padding forzado de ButtonSegment.icon',
      () {
        final source = File(
          'lib/features/settings/presentation/settings_screen.dart',
        ).readAsStringSync();
        expect(source, contains('expandedInsets: EdgeInsets.zero'));
        expect(source, contains('showSelectedIcon: false'));
        expect(source, contains('_ThemeSegmentLabel('));
        expect(source, contains('Icons.brightness_auto'));
        expect(source, contains('Icons.light_mode'));
        expect(source, contains('Icons.dark_mode'));
        expect(source, isNot(contains('icon: Icon(Icons.')));
        expect(source, contains('fontSize: 13'));
        expect(source, contains('horizontal: AppSpacing.xs'));
      },
    );
  });
}
