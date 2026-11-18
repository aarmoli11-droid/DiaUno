import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/time_repository.dart';

final timeRepositoryProvider = Provider<TimeRepository>(
  (ref) => TimeRepository(ref.watch(supabaseProvider)),
);

final activeTimerProvider = FutureProvider<TimeEntry?>((ref) {
  return ref.watch(timeRepositoryProvider).activeTimer();
});

final timeEntriesProvider = FutureProvider<List<TimeEntry>>((ref) {
  return ref.watch(timeRepositoryProvider).listEntries();
});

final timeActionsProvider = NotifierProvider<TimeActions, bool>(
  TimeActions.new,
);

class TimeActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<TimeEntry> start({String? projectId, String? occurrenceId}) async {
    final entry = await ref
        .read(timeRepositoryProvider)
        .startTimer(projectId: projectId, occurrenceId: occurrenceId);
    ref.invalidate(activeTimerProvider);
    ref.invalidate(timeEntriesProvider);
    return entry;
  }

  Future<void> stop(String id) async {
    await ref.read(timeRepositoryProvider).stopTimer(id);
    ref.invalidate(activeTimerProvider);
    ref.invalidate(timeEntriesProvider);
  }

  Future<void> addManual({
    required Duration duration,
    required DateTime date,
    String? projectId,
    String? occurrenceId,
    String description = '',
  }) async {
    await ref
        .read(timeRepositoryProvider)
        .addManualEntry(
          duration: duration,
          date: date,
          projectId: projectId,
          occurrenceId: occurrenceId,
          description: description,
        );
    ref.invalidate(timeEntriesProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(timeRepositoryProvider).deleteEntry(id);
    ref.invalidate(timeEntriesProvider);
  }
}
