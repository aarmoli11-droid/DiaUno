import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/project.dart';

const _projectColumns = '''
id, owner_id, name, description, color_hex, icon_name, status,
start_date, end_date, created_at, updated_at,
project_progress ( progress_percent, garden_points, total_occurrences, completed_occurrences ),
project_members!inner ( role )
''';

class ProjectsRepository {
  ProjectsRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<List<Project>> listProjects() async {
    try {
      final rows = await _client
          .from('projects')
          .select(_projectColumns)
          .eq('project_members.user_id', _userId)
          .order('created_at', ascending: false);
      return rows
          .map((r) => Project.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure('No se pudieron cargar los proyectos: $e');
    }
  }

  Future<Project> getProject(String id) async {
    final row = await _client
        .from('projects')
        .select(_projectColumns)
        .eq('id', id)
        .eq('project_members.user_id', _userId)
        .maybeSingle();
    if (row == null) {
      throw const NotFoundFailure('No tienes acceso a este proyecto.');
    }
    return Project.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Project> createProject(Project project) async {
    final row = await _client
        .from('projects')
        .insert(project.toInsert(_userId))
        .select(_projectColumns)
        .single();
    return Project.fromMap(Map<String, dynamic>.from(row));
  }

  /// Actualización optimista: si updated_at cambió, otro dispositivo ganó.
  Future<Project> updateProject(
    Project project,
    DateTime expectedUpdatedAt,
  ) async {
    final rows = await _client
        .from('projects')
        .update(project.toUpdate(_userId))
        .eq('id', project.id)
        .eq('updated_at', expectedUpdatedAt.toUtc().toIso8601String())
        .select(_projectColumns);
    if (rows.isEmpty) throw const ConflictFailure();
    return Project.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> deleteProject(String id) async {
    await _client.from('projects').delete().eq('id', id);
  }

  Future<List<(String id, String name, String email, ProjectRole role)>>
  listMembers(String projectId) async {
    final rows = await _client
        .from('project_members')
        .select('user_id, role, profiles ( display_name, email )')
        .eq('project_id', projectId);
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final profile =
          map['profiles'] is List && (map['profiles'] as List).isNotEmpty
          ? Map<String, dynamic>.from((map['profiles'] as List).first as Map)
          : <String, dynamic>{};
      return (
        map['user_id'] as String,
        profile['display_name'] as String? ?? 'Usuario',
        profile['email'] as String? ?? '',
        ProjectRoleX.from(map['role'] as String? ?? 'viewer'),
      );
    }).toList();
  }

  Future<void> addMember(
    String projectId,
    String userId,
    ProjectRole role,
  ) async {
    await _client.from('project_members').upsert({
      'project_id': projectId,
      'user_id': userId,
      'role': role.value,
      'invited_by': _userId,
    });
  }

  Future<void> updateMemberRole(
    String projectId,
    String userId,
    ProjectRole role,
  ) async {
    await _client
        .from('project_members')
        .update({'role': role.value})
        .eq('project_id', projectId)
        .eq('user_id', userId);
  }

  Future<void> removeMember(String projectId, String userId) async {
    await _client
        .from('project_members')
        .delete()
        .eq('project_id', projectId)
        .eq('user_id', userId);
  }
}
