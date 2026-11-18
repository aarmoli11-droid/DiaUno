import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.targetType,
    this.targetId,
  });

  final String id;
  final String category;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? targetType;
  final String? targetId;

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'] as String,
    category: map['category'] as String,
    title: map['title'] as String,
    body: map['body'] as String? ?? '',
    isRead: map['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(map['created_at'] as String),
    targetType: map['target_type'] as String?,
    targetId: map['target_id'] as String?,
  );
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<List<AppNotification>> list() async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows
        .map(
          (r) => AppNotification.fromMap(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', _userId)
        .eq('is_read', false);
  }

  Future<void> delete(String id) async {
    await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
