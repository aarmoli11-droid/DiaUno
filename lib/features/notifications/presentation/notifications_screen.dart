import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/async_view.dart';
import '../application/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationsActionsProvider.notifier)
                  .markAllRead();
            },
            child: const Text('Marcar todas'),
          ),
        ],
      ),
      body: AsyncView(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        empty: (list) => list.isEmpty,
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = list[index];
            final p = paletteFor(context);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: item.isRead
                    ? p.surfaceMuted
                    : p.primary.withValues(alpha: 0.15),
                child: Icon(
                  _iconFor(item.category),
                  size: 18,
                  color: item.isRead ? p.textSecondary : p.primary,
                ),
              ),
              title: Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
              subtitle: Text(item.body.isEmpty ? item.category : item.body),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Descartar',
                onPressed: () async {
                  await ref
                      .read(notificationsActionsProvider.notifier)
                      .delete(item.id);
                },
              ),
              onTap: () async {
                if (!item.isRead) {
                  await ref
                      .read(notificationsActionsProvider.notifier)
                      .markRead(item.id);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

IconData _iconFor(String category) => switch (category) {
  'task' => Icons.checklist,
  'finance' => Icons.payments_outlined,
  'project' => Icons.grid_view_outlined,
  'garden' => Icons.eco_outlined,
  _ => Icons.notifications_none,
};
