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
    // No se puede combinar la inserción con `_projectColumns`: el trigger que
    // crea la membresía del owner es AFTER INSERT, por lo que el join `!inner`
    // todavía no ve esa fila y PostgREST devuelve 0 filas (PGRST116). Primero
    // se inserta y, en una sentencia posterior, se lee el proyecto ya completo.
    final inserted = await _client
        .from('projects')
        .insert(project.toInsert(_userId))
        .select('id')
        .single();
    return getProject(inserted['id'] as String);
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
    // Storage exige que la fila padre siga existiendo para borrar el objeto,
    // así que los archivos se eliminan antes que el proyecto. Las filas de
    // `files` desaparecen después por ON DELETE CASCADE. Se recogen también los
    // comprobantes y evidencias enlazados por transaction_id/occurrence_id,
    // porque pueden no repetir project_id en la fila de `files`.
    final files = <dynamic>[
      ...await _client
          .from('files')
          .select('bucket, storage_path')
          .eq('project_id', id),
      ...await _filesFor(
        'transaction_id',
        await _ids('transactions', 'project_id', id),
      ),
      ...await _filesFor('occurrence_id', await _projectOccurrenceIds(id)),
    ];
    await _removeStoredFiles(files);
    await _client.from('projects').delete().eq('id', id);
  }

  Future<List<String>> _ids(String table, String column, String value) async {
    final rows = await _client.from(table).select('id').eq(column, value);
    return rows
        .map((r) => Map<String, dynamic>.from(r as Map)['id'] as String)
        .toList();
  }

  Future<List<String>> _projectOccurrenceIds(String projectId) async {
    final taskIds = await _ids('tasks', 'project_id', projectId);
    if (taskIds.isEmpty) return const <String>[];
    final rows = await _client
        .from('task_occurrences')
        .select('id')
        .inFilter('task_id', taskIds);
    return rows
        .map((r) => Map<String, dynamic>.from(r as Map)['id'] as String)
        .toList();
  }

  Future<List<dynamic>> _filesFor(String column, List<String> ids) async {
    if (ids.isEmpty) return const <dynamic>[];
    return _client
        .from('files')
        .select('bucket, storage_path')
        .inFilter(column, ids);
  }

  Future<void> _removeStoredFiles(List<dynamic> rows) async {
    final byBucket = <String, List<String>>{};
    final seen = <String>{};
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final bucket = map['bucket'] as String?;
      final path = map['storage_path'] as String?;
      if (bucket == null || path == null) continue;
      if (!seen.add('$bucket:$path')) continue;
      byBucket.putIfAbsent(bucket, () => <String>[]).add(path);
    }
    for (final entry in byBucket.entries) {
      await _client.storage.from(entry.key).remove(entry.value);
    }
  }

  /// Sólo se expone el nombre visible; el correo ya no es una columna
  /// seleccionable por los clientes (política de privacidad de perfiles).
  Future<List<(String id, String name, ProjectRole role)>> listMembers(
    String projectId,
  ) async {
    final rows = await _client
        .from('project_members')
        .select('user_id, role, profiles ( display_name )')
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
