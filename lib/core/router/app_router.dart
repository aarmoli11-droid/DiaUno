import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/presentation/agenda_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/finance/presentation/finance_screens.dart';
import '../../features/garden/presentation/garden_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/projects/presentation/projects_screens.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shared/presentation/shared_screen.dart';
import '../../features/tasks/presentation/task_screens.dart';
import '../../features/time/presentation/time_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, _) => refresh.value++);
  ref.listen(passwordRecoveryProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authRepositoryProvider).currentSession != null;
      final onAuth = state.matchedLocation.startsWith('/auth');
      final recovery = ref.read(passwordRecoveryProvider);
      final onNewPassword = state.matchedLocation == '/auth/new-password';

      // Una sesión de recovery es válida pero no debe enviarse a /home:
      // Primero hay que guardar la nueva contraseña.
      if (recovery) {
        return onNewPassword ? null : '/auth/new-password';
      }
      if (!loggedIn && !onAuth) return '/auth/welcome';
      if (loggedIn && onAuth) return '/home';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 40),
              const SizedBox(height: 16),
              Text(
                'Página no encontrada',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ?? 'La ruta no existe.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/auth',
        redirect: (_, state) {
          // El redirect de un GoRoute también se aplica a sus subrutas. Sólo
          // normalizamos la ruta base: redirigir cualquier hija a welcome
          // impedía abrir login, register, reset y new-password.
          if (state.uri.path == '/auth') return '/auth/welcome';
          return null;
        },
        routes: [
          GoRoute(path: 'welcome', builder: (_, _) => const WelcomeScreen()),
          GoRoute(path: 'login', builder: (_, _) => const LoginScreen()),
          GoRoute(path: 'register', builder: (_, _) => const RegisterScreen()),
          GoRoute(
            path: 'reset',
            builder: (_, _) => const ResetPasswordScreen(),
          ),
          GoRoute(
            path: 'new-password',
            builder: (_, _) => const NewPasswordScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (_, _) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: ':projectId',
                    builder: (context, state) => ProjectDetailScreen(
                      projectId: state.pathParameters['projectId']!,
                      tab: state.uri.queryParameters['tab'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (_, _) => const AgendaScreen(),
                routes: [
                  GoRoute(
                    path: 'events/:eventId',
                    builder: (context, state) => EventFormScreen(
                      eventId: state.pathParameters['eventId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shared',
                builder: (_, _) => const SharedScreen(),
                routes: [
                  GoRoute(
                    path: 'subscriptions/:subscriptionId',
                    builder: (context, state) => SubscriptionFormScreen(
                      subscriptionId: state.pathParameters['subscriptionId'],
                    ),
                  ),
                  GoRoute(
                    path: 'distributions/:sourceType/:sourceId',
                    builder: (context, state) => DistributionScreen(
                      sourceType:
                          state.pathParameters['sourceType'] ?? 'subscription',
                      sourceId: state.pathParameters['sourceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/garden', builder: (_, _) => const GardenScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tasks/new',
        builder: (context, state) => TaskFormScreen(
          projectId: state.uri.queryParameters['projectId'],
          dueDate: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/tasks/:occurrenceId',
        builder: (context, state) => TaskDetailScreen(
          occurrenceId: state.pathParameters['occurrenceId']!,
        ),
      ),
      GoRoute(path: '/finance', builder: (_, _) => const FinanceScreen()),
      GoRoute(
        path: '/finance/new',
        builder: (_, _) => const TransactionFormScreen(),
      ),
      GoRoute(path: '/time', builder: (_, _) => const TimeScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/sync',
        builder: (_, _) => const SyncStatusScreen(),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
    ],
  );
});
