import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/providers/core_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/application/sync_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey.isNotEmpty
          ? Env.supabasePublishableKey
          : null,
      // ignore: deprecated_member_use
      anonKey: Env.supabaseAnonKey.isNotEmpty ? Env.supabaseAnonKey : null,
      debug: false,
    );
  }

  runApp(const ProviderScope(child: DiaUnoApp()));
}

class DiaUnoApp extends ConsumerWidget {
  const DiaUnoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isConfigured) {
      return MaterialApp(
        title: 'Configuración pendiente',
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Faltan las variables de Supabase. Ejecuta la app con '
                '--dart-define-from-file=.env.local (consulta README.md).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final store = ref.watch(localStoreProvider);
    final theme = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final router = ref.watch(routerProvider);

    ref.listen<bool>(isOnlineProvider, (previous, next) async {
      if (previous == false && next == true) {
        final sync = await ref.read(syncCoordinatorProvider.future);
        await sync.drain();
      }
    });

    return MaterialApp.router(
      title: 'DíaUno',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme,
      routerConfig: router,
      builder: (context, child) {
        return store.when(
          data: (_) => child ?? const SizedBox.shrink(),
          loading: () =>
              const Material(child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Material(
            child: Center(
              child: Text('No se pudo iniciar el almacenamiento local: $error'),
            ),
          ),
        );
      },
    );
  }
}
