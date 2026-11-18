import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/garden.dart';

class GardenRepository {
  GardenRepository(this._client);

  final SupabaseClient _client;

  Future<List<GardenEvent>> listEvents({String? projectId}) async {
    try {
      var query = _client.from('garden_progress_events').select('''
        id, project_id, points, flower_type, event_type, created_at,
        projects ( name )
      ''');
      if (projectId != null) query = query.eq('project_id', projectId);
      final rows = await query.order('created_at', ascending: false).limit(200);
      return rows.map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        final event = GardenEvent.fromMap(map);
        final project =
            map['projects'] is List && (map['projects'] as List).isNotEmpty
            ? Map<String, dynamic>.from((map['projects'] as List).first as Map)
            : <String, dynamic>{};
        return GardenEvent(
          id: event.id,
          projectId: event.projectId,
          points: event.points,
          flowerType: event.flowerType,
          eventType: event.eventType,
          createdAt: event.createdAt,
          projectName: project['name'] as String?,
        );
      }).toList();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const ServerFailure('No se pudo cargar el jardín.');
    }
  }
}
