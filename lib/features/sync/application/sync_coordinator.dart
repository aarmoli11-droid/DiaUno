import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/sync_service.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../tasks/application/tasks_controller.dart';
import '../../tasks/domain/task.dart';

/// Registra los manejadores reales de cada tipo de mutación offline.
final syncCoordinatorProvider = FutureProvider<SyncService>((ref) async {
  final sync = await ref.watch(syncServiceProvider.future);
  if (sync.hasHandlers) return sync;
  final client = ref.read(supabaseProvider);

  sync.register('task_occurrence_status', (mutation) async {
    final payload = mutation.payload;
    var query = client
        .from('task_occurrences')
        .update({
          'status': payload['status'],
          'completed_at': payload['status'] == 'completed'
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'completed_by': payload['status'] == 'completed'
              ? client.auth.currentUser?.id
              : null,
        })
        .eq('id', payload['occurrenceId'] as String);
    final expected = DateTime.tryParse(
      payload['expectedUpdatedAt'] as String? ?? '',
    );
    if (expected != null) {
      query = query.eq('updated_at', expected.toUtc().toIso8601String());
    }
    final rows = await query.select('id');
    if (rows.isEmpty) throw const ConflictFailure();
    ref.invalidate(taskOccurrencesProvider);
  });

  sync.register('project_update', (mutation) async {
    final payload = mutation.payload;
    var query = client
        .from('projects')
        .update(Map<String, dynamic>.from(payload['project'] as Map))
        .eq('id', payload['id'] as String);
    final expected = DateTime.tryParse(
      payload['expectedUpdatedAt'] as String? ?? '',
    );
    if (expected != null) {
      query = query.eq('updated_at', expected.toUtc().toIso8601String());
    }
    final rows = await query.select('id');
    if (rows.isEmpty) throw const ConflictFailure();
  });

  return sync;
});

/// Utilidad para resolver un conflicto desde la UI.
Future<void> acceptRemote(SyncService sync, String id) => sync.dropConflict(id);
Future<void> keepLocalAndRetry(SyncService sync, String id) =>
    sync.retryConflict(id);

TaskStatus statusFromPayload(String value) => TaskStatusX.from(value);
