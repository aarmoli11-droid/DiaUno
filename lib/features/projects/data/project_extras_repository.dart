import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';

class ExternalTool {
  const ExternalTool({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.url,
    required this.category,
    required this.iconName,
    required this.status,
  });

  final String id;
  final String projectId;
  final String name;
  final String description;
  final String url;
  final String category;
  final String iconName;
  final String status;

  factory ExternalTool.fromMap(Map<String, dynamic> map) => ExternalTool(
    id: map['id'] as String,
    projectId: map['project_id'] as String,
    name: map['name'] as String,
    description: map['description'] as String? ?? '',
    url: map['url'] as String,
    category: map['category'] as String? ?? 'other',
    iconName: map['icon_name'] as String? ?? 'link',
    status: map['status'] as String? ?? 'active',
  );
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.actorName,
  });

  final String id;
  final String action;
  final String entityType;
  final DateTime createdAt;
  final String? actorName;

  factory ActivityItem.fromMap(Map<String, dynamic> map) {
    final profile =
        map['profiles'] is List && (map['profiles'] as List).isNotEmpty
        ? Map<String, dynamic>.from((map['profiles'] as List).first as Map)
        : <String, dynamic>{};
    return ActivityItem(
      id: map['id'] as String,
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      actorName: profile['display_name'] as String?,
    );
  }
}

class ProjectExtrasRepository {
  ProjectExtrasRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<List<ExternalTool>> listTools(String projectId) async {
    final rows = await _client
        .from('external_tools')
        .select()
        .eq('project_id', projectId)
        .order('name');
    return rows
        .map((r) => ExternalTool.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> createTool({
    required String projectId,
    required String name,
    required String url,
    String description = '',
    String category = 'other',
    String iconName = 'link',
  }) async {
    await _client.from('external_tools').insert({
      'project_id': projectId,
      'name': name.trim(),
      'url': url.trim(),
      'description': description.trim(),
      'category': category,
      'icon_name': iconName,
      'status': 'active',
      'created_by': _userId,
    });
  }

  Future<void> deleteTool(String id) async {
    await _client.from('external_tools').delete().eq('id', id);
  }

  Future<List<ActivityItem>> listActivity(String projectId) async {
    final rows = await _client
        .from('activity_log')
        .select(
          'id, action, entity_type, created_at, profiles ( display_name )',
        )
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map((r) => ActivityItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<(String id, String displayName)>> searchProfiles(
    String query,
  ) async {
    if (query.trim().length < 2) return const [];
    final rows = await _client.rpc(
      'search_profiles',
      params: {'p_query': query.trim()},
    );
    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return (m['id'] as String, m['display_name'] as String);
    }).toList();
  }
}
