import 'package:flutter/foundation.dart';

import '../../core/errors/app_failure.dart';
import 'local_store.dart';

class SyncReport {
  const SyncReport({
    required this.sent,
    required this.failed,
    required this.conflicts,
    required this.remaining,
  });

  final int sent;
  final int failed;
  final int conflicts;
  final int remaining;

  bool get isClean => failed == 0 && conflicts == 0 && remaining == 0;
}

typedef MutationHandler = Future<void> Function(PendingMutation mutation);

/// Drena la cola local contra los repositorios remotos.
/// Los conflictos no se descartan: se conservan con su payload para resolverlos.
class SyncService {
  SyncService(this._store);

  final LocalStore _store;
  final Map<String, MutationHandler> _handlers = {};
  final ValueNotifier<bool> running = ValueNotifier(false);
  final ValueNotifier<SyncReport?> lastReport = ValueNotifier(null);

  void register(String entity, MutationHandler handler) =>
      _handlers[entity] = handler;

  bool get hasHandlers => _handlers.isNotEmpty;

  Future<SyncReport> drain() async {
    if (running.value) {
      return lastReport.value ??
          const SyncReport(sent: 0, failed: 0, conflicts: 0, remaining: 0);
    }
    running.value = true;
    var sent = 0;
    var failed = 0;
    var conflicts = 0;
    try {
      for (final mutation in _store.pending()) {
        final handler = _handlers[mutation.entity];
        if (handler == null) {
          mutation.error = 'Sin manejador para ${mutation.entity}';
          await _store.saveMutation(mutation);
          failed++;
          continue;
        }
        try {
          await handler(mutation);
          await _store.removeMutation(mutation.id);
          sent++;
        } on ConflictFailure {
          mutation
            ..status = 'conflict'
            ..error = 'El registro remoto es más reciente.';
          await _store.saveMutation(mutation);
          conflicts++;
        } on AppFailure {
          mutation
            ..attempts = mutation.attempts + 1
            ..error = 'Reintentaremos automáticamente.';
          await _store.saveMutation(mutation);
          failed++;
        } catch (_) {
          mutation
            ..attempts = mutation.attempts + 1
            ..error = 'Error inesperado. Revisa tu conexión.';
          await _store.saveMutation(mutation);
          failed++;
        }
      }
      final report = SyncReport(
        sent: sent,
        failed: failed,
        conflicts: conflicts,
        remaining: _store.mutations().length,
      );
      lastReport.value = report;
      return report;
    } finally {
      running.value = false;
    }
  }

  Future<void> dropConflict(String id) => _store.removeMutation(id);

  Future<void> retryConflict(String id) async {
    final mutation = _store.mutations().firstWhere(
      (m) => m.id == id,
      orElse: () => throw const NotFoundFailure('Conflicto no encontrado.'),
    );
    mutation
      ..status = 'pending'
      ..attempts = 0
      ..error = null;
    await _store.saveMutation(mutation);
  }
}
