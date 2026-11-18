import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_x.dart';

class AgendaEvent {
  const AgendaEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.ownerId,
    this.projectId,
    this.location,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String ownerId;
  final String? projectId;
  final String? location;

  factory AgendaEvent.fromMap(Map<String, dynamic> map) => AgendaEvent(
    id: map['id'] as String,
    title: map['title'] as String,
    description: map['description'] as String? ?? '',
    startsAt: DateTime.parse(map['starts_at'] as String),
    endsAt: DateTime.parse(map['ends_at'] as String),
    allDay: map['all_day'] as bool? ?? false,
    ownerId: map['owner_id'] as String,
    projectId: map['project_id'] as String?,
    location: map['location'] as String?,
  );

  Map<String, dynamic> toInsert(String userId) => {
    'owner_id': userId,
    'created_by': userId,
    'title': title,
    'description': description,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'all_day': allDay,
    'location': location,
    'project_id': projectId,
  };

  Map<String, dynamic> toUpdate() => {
    'title': title,
    'description': description,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'all_day': allDay,
    'location': location,
    'project_id': projectId,
  };
}

class AgendaRepository {
  AgendaRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Inicia sesión para continuar.');
    return user.id;
  }

  Future<List<AgendaEvent>> listEvents(Date from, Date to) async {
    final rows = await _client
        .from('events')
        .select()
        .gte('starts_at', from.toDateTime().toUtc().toIso8601String())
        .lte(
          'starts_at',
          to
              .toDateTime()
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
        )
        .order('starts_at');
    return rows
        .map((r) => AgendaEvent.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<AgendaEvent?> getEvent(String id) async {
    final row = await _client
        .from('events')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null
        ? null
        : AgendaEvent.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AgendaEvent> createEvent(AgendaEvent event) async {
    final row = await _client
        .from('events')
        .insert(event.toInsert(_userId))
        .select()
        .single();
    return AgendaEvent.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateEvent(AgendaEvent event) async {
    await _client.from('events').update(event.toUpdate()).eq('id', event.id);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }
}
