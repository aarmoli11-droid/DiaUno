import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_x.dart';

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.isManual,
    required this.description,
    this.projectId,
    this.occurrenceId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final bool isManual;
  final String description;
  final String? projectId;
  final String? occurrenceId;

  bool get isRunning => endedAt == null;

  factory TimeEntry.fromMap(Map<String, dynamic> map) => TimeEntry(
    id: map['id'] as String,
    startedAt: DateTime.parse(map['started_at'] as String),
    endedAt: map['ended_at'] == null
        ? null
        : DateTime.parse(map['ended_at'] as String),
    durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
    isManual: map['is_manual'] as bool? ?? false,
    description: map['description'] as String? ?? '',
    projectId: map['project_id'] as String?,
    occurrenceId: map['occurrence_id'] as String?,
  );
}

class TimeRepository {
  TimeRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<TimeEntry?> activeTimer() async {
    final row = await _client
        .from('time_entries')
        .select()
        .eq('owner_id', _userId)
        .isFilter('ended_at', null)
        .maybeSingle();
    return row == null
        ? null
        : TimeEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<TimeEntry> startTimer({
    String? projectId,
    String? occurrenceId,
    String description = '',
  }) async {
    if (projectId == null && occurrenceId == null) {
      throw const ValidationFailure(
        'El registro debe vincularse a una tarea o proyecto.',
      );
    }
    final row = await _client
        .from('time_entries')
        .insert({
          'owner_id': _userId,
          'project_id': projectId,
          'occurrence_id': occurrenceId,
          'description': description,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'is_manual': false,
          'duration_seconds': 0,
        })
        .select()
        .single();
    return TimeEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> stopTimer(String id) async {
    final existing = await _client
        .from('time_entries')
        .select('started_at')
        .eq('id', id)
        .single();
    final started = DateTime.parse(existing['started_at'] as String);
    final end = DateTime.now().toUtc();
    await _client
        .from('time_entries')
        .update({
          'ended_at': end.toIso8601String(),
          'duration_seconds': end.difference(started).inSeconds < 0
              ? 0
              : end.difference(started).inSeconds,
        })
        .eq('id', id);
  }

  Future<TimeEntry> addManualEntry({
    required Duration duration,
    required DateTime date,
    String? projectId,
    String? occurrenceId,
    String description = '',
  }) async {
    if (projectId == null && occurrenceId == null) {
      throw const ValidationFailure(
        'El registro debe vincularse a una tarea o proyecto.',
      );
    }
    final end = date.add(duration);
    final row = await _client
        .from('time_entries')
        .insert({
          'owner_id': _userId,
          'project_id': projectId,
          'occurrence_id': occurrenceId,
          'description': description,
          'started_at': date.toUtc().toIso8601String(),
          'ended_at': end.toUtc().toIso8601String(),
          'duration_seconds': duration.inSeconds,
          'is_manual': true,
        })
        .select()
        .single();
    return TimeEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<TimeEntry>> listEntries({Date? from, Date? to}) async {
    var query = _client.from('time_entries').select().eq('owner_id', _userId);
    if (from != null) {
      query = query.gte(
        'started_at',
        from.toDateTime().toUtc().toIso8601String(),
      );
    }
    if (to != null) {
      query = query.lte(
        'started_at',
        to.toDateTime().add(const Duration(days: 1)).toUtc().toIso8601String(),
      );
    }
    final rows = await query.order('started_at', ascending: false);
    return rows
        .map((r) => TimeEntry.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('time_entries').delete().eq('id', id);
  }
}
