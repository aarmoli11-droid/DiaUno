import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_store.dart';
import '../data/sync_service.dart';
import '../theme/tokens.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final store = LocalStore();
  await store.init();
  ref.onDispose(store.close);
  return store;
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final store = await ref.watch(localStoreProvider.future);
  return SyncService(store);
});

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  yield online(await connectivity.checkConnectivity());
  await for (final result in connectivity.onConnectivityChanged) {
    yield online(result);
  }
});

final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);

/// Se incrementa cuando una mutación afecta a varias pantallas a la vez.
/// `homeDataProvider` lo observa para no depender de imports circulares entre
/// los controladores de cada módulo.
final appDataRevisionProvider =
    NotifierProvider<AppDataRevisionController, int>(
      AppDataRevisionController.new,
    );

class AppDataRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final store = await ref.watch(localStoreProvider.future);
    final value = store.readPref('theme_mode');
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final store = await ref.read(localStoreProvider.future);
    await store.writePref('theme_mode', mode.name);
  }
}

/// Paleta activa derivada del brillo resuelto por el sistema.
Palette paletteFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.dark
    : AppColors.light;
