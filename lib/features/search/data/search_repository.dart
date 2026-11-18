import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';

enum SearchKind { project, task, event, subscription }

class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.targetRoute,
  });

  final SearchKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String? targetRoute;
}

class SearchRepository {
  SearchRepository(this._client);

  final SupabaseClient _client;

  Future<List<SearchHit>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return const [];
    final pattern = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
    final hits = <SearchHit>[];

    try {
      final projects = await _client
          .from('projects')
          .select('id, name, description')
          .or('name.ilike.$pattern,description.ilike.$pattern')
          .limit(20);
      for (final r in projects) {
        final m = Map<String, dynamic>.from(r as Map);
        hits.add(
          SearchHit(
            kind: SearchKind.project,
            id: m['id'] as String,
            title: m['name'] as String,
            subtitle: m['description'] as String? ?? 'Proyecto',
            targetRoute: '/projects/${m['id']}',
          ),
        );
      }

      final tasks = await _client
          .from('tasks')
          .select('id, title, description, project_id')
          .or('title.ilike.$pattern,description.ilike.$pattern')
          .limit(20);
      for (final r in tasks) {
        final m = Map<String, dynamic>.from(r as Map);
        hits.add(
          SearchHit(
            kind: SearchKind.task,
            id: m['id'] as String,
            title: m['title'] as String,
            subtitle: m['description'] as String? ?? 'Tarea',
            targetRoute: m['project_id'] == null
                ? '/tasks/${m['id']}'
                : '/projects/${m['project_id']}?tab=tasks',
          ),
        );
      }

      final events = await _client
          .from('events')
          .select('id, title, starts_at')
          .ilike('title', pattern)
          .limit(20);
      for (final r in events) {
        final m = Map<String, dynamic>.from(r as Map);
        hits.add(
          SearchHit(
            kind: SearchKind.event,
            id: m['id'] as String,
            title: m['title'] as String,
            subtitle: 'Agenda',
            targetRoute: '/agenda',
          ),
        );
      }

      final subscriptions = await _client
          .from('subscriptions')
          .select('id, name, provider')
          .ilike('name', pattern)
          .limit(20);
      for (final r in subscriptions) {
        final m = Map<String, dynamic>.from(r as Map);
        hits.add(
          SearchHit(
            kind: SearchKind.subscription,
            id: m['id'] as String,
            title: m['name'] as String,
            subtitle: m['provider'] as String? ?? 'Suscripción',
            targetRoute: '/shared',
          ),
        );
      }
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const ServerFailure('No se pudo completar la búsqueda.');
    }
    return hits;
  }
}
