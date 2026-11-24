import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/tokens.dart';

/// Estado de sincronización siempre visible cuando hay algo que comunicar.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key, required this.visible});

  /// Lo calcula el shell para poder quitar el `SafeArea` superior de la pantalla
  /// cuando el aviso ocupa ese hueco; así no se duplica el padding en móvil.
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final storeAsync = ref.watch(localStoreProvider);
    final store = storeAsync.value;
    final pending = store?.pending().length ?? 0;
    final conflicts = store?.conflicts().length ?? 0;

    if (!visible || (online && pending == 0 && conflicts == 0)) {
      return const SizedBox.shrink();
    }

    final p = paletteFor(context);
    final color = !online ? p.warning : (conflicts > 0 ? p.error : p.accent);
    final icon = !online
        ? Icons.cloud_off_outlined
        : (conflicts > 0 ? Icons.merge_type : Icons.sync_problem_outlined);
    final text = !online
        ? 'Sin conexión · $pending cambio(s) pendiente(s)'
        : conflicts > 0
        ? '$conflicts conflicto(s) de sincronización requieren tu decisión'
        : 'Sincronizando $pending cambio(s)…';

    final topInset = MediaQuery.paddingOf(context).top;
    return Material(
      color: color.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () => context.push('/settings/sync'),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                topInset + AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      compact
                          ? (text.split('·').first.trim().isEmpty
                                ? text
                                : text.split('·').first.trim())
                          : text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.chevron_right, size: 18, color: color),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
