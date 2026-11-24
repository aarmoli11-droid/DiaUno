import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/garden.dart';

class GardenRepository {
  GardenRepository(this._client);

  final SupabaseClient _client;

  /// El embed debe ir sin espacios: `projects ( name )` hace que PostgREST
  /// ignore la proyección y devuelva todas las columnas sin el nombre.
  static const _columns =
      'id, project_id, points, flower_type, event_type, created_at, projects(name)';

  Future<List<GardenEvent>> listEvents({String? projectId}) async {
    try {
      var query = _client.from('garden_progress_events').select(_columns);
      if (projectId != null) query = query.eq('project_id', projectId);
      final rows = await query.order('created_at', ascending: false).limit(200);
      return rows
          .map((r) => GardenEvent.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on AppFailure {
      rethrow;
    } catch (e) {
      // Se conserva la excepción original para no enmascarar fallos de
      // serialización, permisos o consulta detrás de un mensaje genérico.
      throw ServerFailure('No se pudo cargar el jardín: $e', code: 'garden');
    }
  }
}
