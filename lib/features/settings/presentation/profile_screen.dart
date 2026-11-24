import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../application/settings_controller.dart';

/// Vista de cuenta pensada para pantallas pequeñas: tema y sesión sin tener
/// que entrar en Ajustes.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = paletteFor(context);
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final profile = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    final signingOut = ref.watch(authActionsProvider);
    final displayName =
        profile.value?.displayName ??
        (user?.userMetadata ?? const {})['display_name'] as String? ??
        'Usuario';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: p.primary.withValues(alpha: 0.14),
                        child: Icon(Icons.person_outline, color: p.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (user?.email case final email?)
                              Text(
                                email,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: p.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Apariencia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
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
                  onSelectionChanged: signingOut
                      ? null
                      : (values) async {
                          await ref
                              .read(settingsActionsProvider.notifier)
                              .setTheme(values.first);
                        },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Cuenta', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Ajustes completos'),
                  subtitle: const Text('Sincronización y preferencias.'),
                  onTap: () => context.push('/settings'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: p.error),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(color: p.error),
                  ),
                  trailing: signingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: signingOut
                      ? null
                      : () async {
                          await ref
                              .read(authActionsProvider.notifier)
                              .signOut();
                          if (context.mounted) context.go('/auth/welcome');
                        },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '${Brand.name} ${Brand.version} · ${Brand.tagline}',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
