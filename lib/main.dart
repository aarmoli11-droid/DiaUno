import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/providers/core_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/sync/application/sync_coordinator.dart';

/// Prepara los recursos globales que necesita la app antes de iniciar.
Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat necesita los datos de locale cargados antes de formatear
  // fechas en Inicio, Agenda o al guardar un proyecto.
  await initializeDateFormatting();
  await initializeDateFormatting('es', null);
}

Future<void> main() async {
  await initializeApp();

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.apiKey,
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
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                Env.configurationMessage,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    // Mantener vivas las suscripciones de auth desde el primer frame: sin
    // ellas, un evento `passwordRecovery` recibido en la bienvenida no llega
    // al controlador sticky y el router no puede proteger su ruta especial.
    ref.watch(authEventProvider);
    ref.watch(authSessionProvider);

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
        return ScrollConfiguration(
          behavior: const DiaUnoScrollBehavior(),
          child: store.when(
            data: (_) => child ?? const SizedBox.shrink(),
            loading: () => const Material(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Material(
              child: Center(
                child: Text(
                  'No se pudo iniciar el almacenamiento local: $error',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
