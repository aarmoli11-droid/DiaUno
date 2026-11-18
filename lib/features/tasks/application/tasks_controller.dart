import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/local_store.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_x.dart';
import '../../auth/application/auth_controller.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';

typedef TaskScope = ({Date from, Date to, String? projectId});

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(supabaseProvider)),
);

final taskOccurrencesProvider =
    FutureProvider.family<List<TaskOccurrence>, TaskScope>((ref, scope) {
      return ref
          .watch(tasksRepositoryProvider)
          .listOccurrences(
            from: scope.from,
            to: scope.to,
            projectId: scope.projectId,
          );
    });

final taskDetailProvider = FutureProvider.family<TaskItem?, String>((
  ref,
  id,
) async {
  return ref.watch(tasksRepositoryProvider).getTask(id);
});

final taskDetailOccurrenceProvider =
    FutureProvider.family<TaskOccurrence?, String>((ref, id) async {
      return ref.watch(tasksRepositoryProvider).getOccurrence(id);
    });

final taskCommentsProvider = FutureProvider.family<List<TaskComment>, String>((
  ref,
  occurrenceId,
) {
  return ref.watch(tasksRepositoryProvider).listComments(occurrenceId);
});

final taskEvidenceProvider =
    FutureProvider.family<List<(String id, String name, String path)>, String>((
      ref,
      occurrenceId,
    ) {
      return ref.watch(tasksRepositoryProvider).listEvidence(occurrenceId);
    });

final taskActionsProvider = NotifierProvider<TaskActions, bool>(
  TaskActions.new,
);

class TaskActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<TaskItem> create(TaskItem task) async {
    final created = await ref.read(tasksRepositoryProvider).createTask(task);
    ref.invalidate(taskOccurrencesProvider);
    return created;
  }

  Future<void> update(TaskItem task) async {
    await ref.read(tasksRepositoryProvider).updateTask(task);
    ref.invalidate(taskOccurrencesProvider);
    ref.invalidate(taskDetailProvider(task.id));
  }

  Future<void> delete(String id) async {
    await ref.read(tasksRepositoryProvider).deleteTask(id);
    ref.invalidate(taskOccurrencesProvider);
  }

  /// Cambio de estado con soporte offline y detección de conflictos.
  Future<void> setStatus(
    String occurrenceId,
    TaskStatus status, {
    DateTime? expectedUpdatedAt,
  }) async {
    if (!ref.read(isOnlineProvider)) {
      final store = await ref.read(localStoreProvider.future);
      await store.enqueue(
        PendingMutation(
          id: const Uuid().v4(),
          entity: 'task_occurrence_status',
          operation: 'update',
          payload: {
            'occurrenceId': occurrenceId,
            'status': status.value,
            'expectedUpdatedAt': expectedUpdatedAt?.toIso8601String(),
          },
          createdAt: DateTime.now(),
        ),
      );
      return;
    }
    await ref
        .read(tasksRepositoryProvider)
        .setOccurrenceStatus(
          occurrenceId,
          status,
          expectedUpdatedAt: expectedUpdatedAt,
        );
    ref.invalidate(taskOccurrencesProvider);
  }

  Future<void> addComment(String occurrenceId, String body) async {
    await ref.read(tasksRepositoryProvider).addComment(occurrenceId, body);
    ref.invalidate(taskCommentsProvider(occurrenceId));
  }

  Future<void> uploadEvidence({
    required String occurrenceId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? projectId,
  }) async {
    await ref
        .read(tasksRepositoryProvider)
        .uploadEvidence(
          occurrenceId: occurrenceId,
          bytes: Uint8List.fromList(bytes),
          fileName: fileName,
          mimeType: mimeType,
          projectId: projectId,
        );
    ref.invalidate(taskEvidenceProvider(occurrenceId));
  }

  Future<void> materializeRecurrences(String taskId, Date until) async {
    await ref
        .read(tasksRepositoryProvider)
        .materializeOccurrences(taskId, until);
    ref.invalidate(taskOccurrencesProvider);
  }

  Future<String> currentUserId() async =>
      ref.read(currentUserProvider)?.id ?? '';
}
