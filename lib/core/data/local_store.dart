import 'package:hive_ce_flutter/hive_flutter.dart';

/// Mutación pendiente de sincronización. Guarda el estado local, nunca secretos.
class PendingMutation {
  PendingMutation({
    required this.id,
    required this.entity,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.status = 'pending',
    this.error,
  });

  final String id;
  final String entity;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int attempts;
  String status;
  String? error;

  factory PendingMutation.fromJson(Map<dynamic, dynamic> json) =>
      PendingMutation(
        id: json['id'] as String,
        entity: json['entity'] as String,
        operation: json['operation'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        attempts: json['attempts'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity': entity,
    'operation': operation,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    'status': status,
    'error': error,
  };

  bool get isConflict => status == 'conflict';
}

/// Persistencia local ligera: cola de origen de cambios + caché de lectura.
class LocalStore {
  Box<dynamic>? _outbox;
  Box<dynamic>? _cache;
  Box<dynamic>? _prefs;

  Future<void> init() async {
    if (_outbox != null) return;
    await Hive.initFlutter();
    _outbox = await Hive.openBox<dynamic>('diauno_outbox');
    _cache = await Hive.openBox<dynamic>('diauno_cache');
    _prefs = await Hive.openBox<dynamic>('diauno_prefs');
  }

  bool get isReady => _outbox != null;

  List<PendingMutation> mutations() {
    final box = _outbox;
    if (box == null) return const [];
    return box.values
        .map(
          (v) => PendingMutation.fromJson(Map<dynamic, dynamic>.from(v as Map)),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<PendingMutation> pending() =>
      mutations().where((m) => !m.isConflict).toList();

  List<PendingMutation> conflicts() =>
      mutations().where((m) => m.isConflict).toList();

  Future<void> enqueue(PendingMutation mutation) async {
    await _outbox?.put(mutation.id, mutation.toJson());
  }

  Future<void> saveMutation(PendingMutation mutation) async {
    await _outbox?.put(mutation.id, mutation.toJson());
  }

  Future<void> removeMutation(String id) async => _outbox?.delete(id);

  Future<void> clearAll() async {
    await _outbox?.clear();
    await _cache?.clear();
  }

  Map<dynamic, dynamic>? readCache(String key) {
    final value = _cache?.get(key);
    return value == null ? null : Map<dynamic, dynamic>.from(value as Map);
  }

  List<Map<dynamic, dynamic>> readCacheList(String key) {
    final value = _cache?.get(key) as List<dynamic>?;
    return value?.map((e) => Map<dynamic, dynamic>.from(e as Map)).toList() ??
        const [];
  }

  Future<void> writeCache(String key, Object value) async =>
      _cache?.put(key, value);

  String? readPref(String key) => _prefs?.get(key) as String?;

  Future<void> writePref(String key, String value) async =>
      _prefs?.put(key, value);

  void close() {
    _outbox?.close();
    _cache?.close();
    _prefs?.close();
    _outbox = null;
    _cache = null;
    _prefs = null;
  }
}
