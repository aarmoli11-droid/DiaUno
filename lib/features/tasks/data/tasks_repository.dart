import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_x.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart';

const _taskColumns = '''
id, title, description, priority, recurrence, recurrence_interval,
start_date, recurrence_end_date, due_time, estimated_minutes,
project_id, assigned_to, created_by
''';

class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<List<TaskOccurrence>> listOccurrences({
    Date? from,
    Date? to,
    String? projectId,
  }) async {
    try {
      var query = _client.from('task_occurrences').select('''
        id, task_id, due_date, status, completed_at, completed_by,
        tasks ( $_taskColumns )
      ''');
      if (from != null) query = query.gte('due_date', from.iso);
      if (to != null) query = query.lte('due_date', to.iso);
      final rows = await query.order('due_date');
      return rows
          .map((r) {
            final map = Map<String, dynamic>.from(r as Map);
            return TaskOccurrence.fromMap(map);
          })
          .where((o) {
            if (projectId == null) return true;
            return o.task?.projectId == projectId;
          })
          .toList();
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure('No se pudieron cargar las tareas: $e');
    }
  }

  Future<TaskOccurrence?> getOccurrence(String id) async {
    final row = await _client
        .from('task_occurrences')
        .select('''
          id, task_id, due_date, status, completed_at, completed_by,
          tasks ( $_taskColumns )
        ''')
        .eq('id', id)
        .maybeSingle();
    return row == null
        ? null
        : TaskOccurrence.fromMap(Map<String, dynamic>.from(row));
  }

  Future<TaskItem?> getTask(String id) async {
    final row = await _client
        .from('tasks')
        .select(_taskColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null
        ? null
        : TaskItem.fromMap(Map<String, dynamic>.from(row));
  }

  Future<TaskItem> createTask(TaskItem task) async {
    final row = await _client
        .from('tasks')
        .insert(task.toInsert(_userId))
        .select(_taskColumns)
        .single();
    return TaskItem.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateTask(TaskItem task) async {
    await _client.from('tasks').update(task.toUpdate()).eq('id', task.id);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  /// Materializa las ocurrencias futuras de una serie recurrente.
  /// Cada una es un registro propio con su historial.
  Future<int> materializeOccurrences(String taskId, Date until) async {
    final task = await getTask(taskId);
    if (task == null || task.recurrence == Recurrence.none) return 0;
    final dates = generateOccurrences(
      start: task.startDate,
      recurrence: task.recurrence,
      interval: task.recurrenceInterval,
      endDate: task.recurrenceEndDate,
      until: until,
    );
    if (dates.isEmpty) return 0;
    final rows = dates
        .map((d) => {'task_id': taskId, 'due_date': d.iso, 'status': 'pending'})
        .toList();
    await _client
        .from('task_occurrences')
        .upsert(rows, onConflict: 'task_id,due_date');
    return rows.length;
  }

  Future<TaskOccurrence> setOccurrenceStatus(
    String occurrenceId,
    TaskStatus status, {
    DateTime? expectedUpdatedAt,
  }) async {
    final payload = <String, dynamic>{
      'status': status.value,
      if (status == TaskStatus.completed)
        'completed_at': DateTime.now().toUtc().toIso8601String()
      else
        'completed_at': null,
      'completed_by': status == TaskStatus.completed ? _userId : null,
    };
    var query = _client
        .from('task_occurrences')
        .update(payload)
        .eq('id', occurrenceId);
    if (expectedUpdatedAt != null) {
      query = query.eq(
        'updated_at',
        expectedUpdatedAt.toUtc().toIso8601String(),
      );
    }
    final rows = await query.select('''
      id, task_id, due_date, status, completed_at, completed_by,
      tasks ( $_taskColumns )
    ''');
    if (rows.isEmpty) throw const ConflictFailure();
    return TaskOccurrence.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<List<TaskComment>> listComments(String occurrenceId) async {
    final rows = await _client
        .from('task_comments')
        .select(
          'id, occurrence_id, author_id, body, created_at, profiles ( display_name )',
        )
        .eq('occurrence_id', occurrenceId)
        .order('created_at');
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      final profile =
          map['profiles'] is List && (map['profiles'] as List).isNotEmpty
          ? Map<String, dynamic>.from((map['profiles'] as List).first as Map)
          : <String, dynamic>{};
      final comment = TaskComment.fromMap(map);
      return TaskComment(
        id: comment.id,
        occurrenceId: comment.occurrenceId,
        authorId: comment.authorId,
        body: comment.body,
        createdAt: comment.createdAt,
        authorName: profile['display_name'] as String?,
      );
    }).toList();
  }

  Future<void> addComment(String occurrenceId, String body) async {
    await _client.from('task_comments').insert({
      'occurrence_id': occurrenceId,
      'author_id': _userId,
      'body': body.trim(),
    });
  }

  /// Evidencia en Storage privado; la fila defiles enlaza el archivo con la ocurrencia.
  Future<String> uploadEvidence({
    required String occurrenceId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? projectId,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$_userId/tasks/$occurrenceId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from('task-evidence')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    await _client.from('files').insert({
      'owner_id': _userId,
      'uploaded_by': _userId,
      'project_id': projectId,
      'occurrence_id': occurrenceId,
      'bucket': 'task-evidence',
      'storage_path': path,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': bytes.length,
    });
    return path;
  }

  Future<List<(String id, String name, String path)>> listEvidence(
    String occurrenceId,
  ) async {
    final rows = await _client
        .from('files')
        .select('id, file_name, storage_path')
        .eq('occurrence_id', occurrenceId);
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      return (
        map['id'] as String,
        map['file_name'] as String,
        map['storage_path'] as String,
      );
    }).toList();
  }

  Future<String> signedEvidenceUrl(String path) async {
    return _client.storage.from('task-evidence').createSignedUrl(path, 3600);
  }
}
