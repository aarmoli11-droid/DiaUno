import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(supabaseProvider)),
);

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationsRepositoryProvider).list();
});

final notificationsActionsProvider =
    NotifierProvider<NotificationsActions, bool>(NotificationsActions.new);

class NotificationsActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> markRead(String id) async {
    await ref.read(notificationsRepositoryProvider).markRead(id);
    ref.invalidate(notificationsProvider);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    ref.invalidate(notificationsProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(notificationsRepositoryProvider).delete(id);
    ref.invalidate(notificationsProvider);
  }
}
