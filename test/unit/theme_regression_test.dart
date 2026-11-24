import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diauno/core/data/local_store.dart';
import 'package:diauno/core/providers/core_providers.dart';

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

class _ThemeHarness extends ConsumerWidget {
  const _ThemeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('MODO=${mode.name}'),
            for (final value in ThemeMode.values)
              FilledButton(
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).setMode(value),
                child: Text('SET_${value.name.toUpperCase()}'),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('el tema sigue seleccionándose y persistiéndose', (tester) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWith((ref) async => store)],
        child: const _ThemeHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MODO=system'), findsOneWidget);

    await tester.tap(find.text('SET_DARK'));
    await tester.pumpAndSettle();

    expect(find.text('MODO=dark'), findsOneWidget);
    expect(store.prefs['theme_mode'], 'dark');

    await tester.tap(find.text('SET_LIGHT'));
    await tester.pumpAndSettle();

    expect(find.text('MODO=light'), findsOneWidget);
    expect(store.prefs['theme_mode'], 'light');
  });
}
