import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/brand.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/async_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../sync/application/sync_coordinator.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = paletteFor(context);
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final profile = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Cuenta',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        profile.value?.displayName ??
                            (user?.userMetadata ?? const {})['display_name']
                                as String? ??
                            'Usuario',
                      ),
                      subtitle: Text(user?.email ?? ''),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sync_problem_outlined),
                      title: const Text('Estado de sincronización'),
                      subtitle: const Text(
                        'Revisa cambios pendientes y conflictos.',
                      ),
                      onTap: () => context.push('/settings/sync'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  title: 'Apariencia',
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        'Tema',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Oscuro'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (values) async {
                        await ref
                            .read(settingsActionsProvider.notifier)
                            .setTheme(values.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  title: 'Datos',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.login_outlined),
                      title: const Text('Cerrar sesión'),
                      onTap: () async {
                        await ref.read(authActionsProvider.notifier).signOut();
                        if (context.mounted) context.go('/auth/welcome');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  title: 'Acerca de',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.eco_outlined, color: p.primary),
                      title: Text('${Brand.name} ${Brand.version}'),
                      subtitle: Text(Brand.tagline),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacidad y términos'),
                      subtitle: const Text(
                        'Pendiente de publicar la política oficial.',
                      ),
                      onTap: () async {
                        const url = 'https://supabase.com/privacy';
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncCoordinatorProvider);
    final store = ref.watch(localStoreProvider);
    final mutations = store.value?.mutations() ?? const [];
    final online = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online ? 'Conectado' : 'Sin conexión',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${store.value?.pending().length ?? 0} cambio(s) pendiente(s) · '
                          '${store.value?.conflicts().length ?? 0} conflicto(s)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        sync.when(
                          data: (service) => FilledButton.icon(
                            onPressed: online
                                ? () async {
                                    final report = await service.drain();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Enviados: ${report.sent} · Fallidos: ${report.failed} · Conflictos: ${report.conflicts}',
                                          ),
                                        ),
                                      );
                                    }
                                    ref.invalidate(localStoreProvider);
                                  }
                                : null,
                            icon: const Icon(Icons.sync),
                            label: const Text('Sincronizar ahora'),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('No se pudo iniciar: $e'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Cola local',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (mutations.isEmpty)
                  const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Todo al día',
                    message: 'No hay cambios pendientes de sincronizar.',
                  )
                else
                  ...mutations.map(
                    (m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        m.isConflict ? Icons.merge_type : Icons.pending_actions,
                        color: m.isConflict
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      title: Text('${m.entity} · ${m.operation}'),
                      subtitle: Text(m.error ?? m.createdAt.toIso8601String()),
                      trailing: m.isConflict
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final service = await ref.read(
                                      syncCoordinatorProvider.future,
                                    );
                                    await acceptRemote(service, m.id);
                                    ref.invalidate(localStoreProvider);
                                  },
                                  child: const Text('Usar remoto'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final service = await ref.read(
                                      syncCoordinatorProvider.future,
                                    );
                                    await keepLocalAndRetry(service, m.id);
                                    ref.invalidate(localStoreProvider);
                                  },
                                  child: const Text('Reintentar local'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
