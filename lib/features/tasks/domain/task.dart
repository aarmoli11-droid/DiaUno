import '../../../core/utils/date_x.dart';

enum TaskStatus { pending, inProgress, completed, cancelled }

enum TaskPriority { low, medium, high, urgent }

enum Recurrence { none, daily, weekly, monthly }

extension TaskStatusX on TaskStatus {
  String get value => switch (this) {
    TaskStatus.pending => 'pending',
    TaskStatus.inProgress => 'in_progress',
    TaskStatus.completed => 'completed',
    TaskStatus.cancelled => 'cancelled',
  };
  String get label => switch (this) {
    TaskStatus.pending => 'Pendiente',
    TaskStatus.inProgress => 'En progreso',
    TaskStatus.completed => 'Completada',
    TaskStatus.cancelled => 'Cancelada',
  };
  static TaskStatus from(String value) => switch (value) {
    'in_progress' => TaskStatus.inProgress,
    'completed' => TaskStatus.completed,
    'cancelled' => TaskStatus.cancelled,
    _ => TaskStatus.pending,
  };
}

extension TaskPriorityX on TaskPriority {
  String get value => name;
  String get label => switch (this) {
    TaskPriority.low => 'Baja',
    TaskPriority.medium => 'Media',
    TaskPriority.high => 'Alta',
    TaskPriority.urgent => 'Urgente',
  };
  static TaskPriority from(String value) => TaskPriority.values.firstWhere(
    (p) => p.name == value,
    orElse: () => TaskPriority.medium,
  );
}

extension RecurrenceX on Recurrence {
  String get value => name;
  String get label => switch (this) {
    Recurrence.none => 'Sin repetición',
    Recurrence.daily => 'Diaria',
    Recurrence.weekly => 'Semanal',
    Recurrence.monthly => 'Mensual',
  };
  static Recurrence from(String value) => Recurrence.values.firstWhere(
    (r) => r.name == value,
    orElse: () => Recurrence.none,
  );
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.recurrence,
    required this.recurrenceInterval,
    required this.startDate,
    this.recurrenceEndDate,
    this.dueTime,
    this.projectId,
    this.assignedTo,
    required this.createdBy,
    required this.estimatedMinutes,
    this.currentOccurrenceId,
    this.occurrenceStatus,
    this.occurrenceDueDate,
  });

  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final Recurrence recurrence;
  final int recurrenceInterval;
  final Date startDate;
  final Date? recurrenceEndDate;
  final String? dueTime;
  final String? projectId;
  final String? assignedTo;
  final String createdBy;
  final int estimatedMinutes;
  final String? currentOccurrenceId;
  final TaskStatus? occurrenceStatus;
  final Date? occurrenceDueDate;

  bool get isPersonal => projectId == null;

  factory TaskItem.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? occurrence,
  }) {
    final occ = occurrence ?? _firstFromList(map['task_occurrences']);
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: TaskPriorityX.from(map['priority'] as String? ?? 'medium'),
      recurrence: RecurrenceX.from(map['recurrence'] as String? ?? 'none'),
      recurrenceInterval: (map['recurrence_interval'] as num?)?.toInt() ?? 1,
      startDate:
          Date.tryParse(map['start_date'] as String? ?? '') ?? Date.today(),
      recurrenceEndDate: Date.tryParse(map['recurrence_end_date'] as String?),
      dueTime: map['due_time'] as String?,
      projectId: map['project_id'] as String?,
      assignedTo: map['assigned_to'] as String?,
      createdBy: map['created_by'] as String,
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt() ?? 0,
      currentOccurrenceId: occ?['id'] as String?,
      occurrenceStatus: occ == null
          ? null
          : TaskStatusX.from(occ['status'] as String? ?? 'pending'),
      occurrenceDueDate: Date.tryParse(occ?['due_date'] as String?),
    );
  }

  static Map<String, dynamic>? _firstFromList(Object? value) {
    if (value is List && value.isNotEmpty) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  Map<String, dynamic> toInsert(String userId) => {
    'project_id': projectId,
    'created_by': userId,
    'updated_by': userId,
    'assigned_to': assignedTo,
    'title': title,
    'description': description,
    'priority': priority.value,
    'recurrence': recurrence.value,
    'recurrence_interval': recurrenceInterval,
    'recurrence_end_date': recurrenceEndDate?.iso,
    'start_date': startDate.iso,
    'due_time': dueTime,
    'estimated_minutes': estimatedMinutes,
  };

  Map<String, dynamic> toUpdate() => {
    'title': title,
    'description': description,
    'priority': priority.value,
    'recurrence': recurrence.value,
    'recurrence_interval': recurrenceInterval,
    'recurrence_end_date': recurrenceEndDate?.iso,
    'start_date': startDate.iso,
    'due_time': dueTime,
    'estimated_minutes': estimatedMinutes,
    'assigned_to': assignedTo,
  };
}

class TaskOccurrence {
  const TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.dueDate,
    required this.status,
    this.completedAt,
    this.completedBy,
    this.task,
  });

  final String id;
  final String taskId;
  final Date dueDate;
  final TaskStatus status;
  final DateTime? completedAt;
  final String? completedBy;
  final TaskItem? task;

  factory TaskOccurrence.fromMap(Map<String, dynamic> map, {TaskItem? task}) {
    final rawMap = task == null ? _firstFromList(map['tasks']) : null;
    return TaskOccurrence(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      dueDate: Date.tryParse(map['due_date'] as String? ?? '') ?? Date.today(),
      status: TaskStatusX.from(map['status'] as String? ?? 'pending'),
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      completedBy: map['completed_by'] as String?,
      task: task ?? (rawMap == null ? null : TaskItem.fromMap(rawMap)),
    );
  }

  static Map<String, dynamic>? _firstFromList(Object? value) {
    if (value is List && value.isNotEmpty) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.occurrenceId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String occurrenceId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final String? authorName;

  factory TaskComment.fromMap(Map<String, dynamic> map) => TaskComment(
    id: map['id'] as String,
    occurrenceId: map['occurrence_id'] as String,
    authorId: map['author_id'] as String,
    body: map['body'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    authorName: map['display_name'] as String?,
  );
}
