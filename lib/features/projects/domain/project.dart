import '../../../core/utils/date_x.dart';

enum ProjectRole { owner, admin, collaborator, viewer }

extension ProjectRoleX on ProjectRole {
  String get value => name;
  bool get canEdit => this == ProjectRole.owner || this == ProjectRole.admin;
  bool get canWriteTasks =>
      this == ProjectRole.owner ||
      this == ProjectRole.admin ||
      this == ProjectRole.collaborator;

  static ProjectRole from(String value) => ProjectRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => ProjectRole.viewer,
  );
}

class Project {
  const Project({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.colorHex,
    required this.iconName,
    required this.status,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.progressPercent = 0,
    this.gardenPoints = 0,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.myRole,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String colorHex;
  final String iconName;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int progressPercent;
  final int gardenPoints;
  final int totalTasks;
  final int completedTasks;
  final ProjectRole? myRole;

  bool get isArchived => status == 'archived';

  factory Project.fromMap(Map<String, dynamic> map) {
    final rawProgress = map['project_progress'];
    Map<String, dynamic>? progress;
    if (rawProgress is List && rawProgress.isNotEmpty) {
      progress = Map<String, dynamic>.from(rawProgress.first as Map);
    } else if (rawProgress is Map) {
      progress = Map<String, dynamic>.from(rawProgress);
    }
    final role = map['project_members'];
    ProjectRole? myRole;
    if (role is List && role.isNotEmpty) {
      final raw = Map<String, dynamic>.from(role.first as Map);
      myRole = ProjectRoleX.from(raw['role'] as String? ?? 'viewer');
    }

    return Project(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      colorHex: map['color_hex'] as String? ?? '#2E6B4E',
      iconName: map['icon_name'] as String? ?? 'folder',
      status: map['status'] as String? ?? 'active',
      startDate: parseDateOrNull(map['start_date'] as String?),
      endDate: parseDateOrNull(map['end_date'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      progressPercent: (progress?['progress_percent'] as num?)?.toInt() ?? 0,
      gardenPoints: (progress?['garden_points'] as num?)?.toInt() ?? 0,
      totalTasks: (progress?['total_occurrences'] as num?)?.toInt() ?? 0,
      completedTasks:
          (progress?['completed_occurrences'] as num?)?.toInt() ?? 0,
      myRole: myRole,
    );
  }

  Map<String, dynamic> toInsert(String userId) => {
    'owner_id': userId,
    'name': name,
    'description': description,
    'color_hex': colorHex,
    'icon_name': iconName,
    'status': status,
    'start_date': startDate?.yyyyMmDd,
    'end_date': endDate?.yyyyMmDd,
    'created_by': userId,
    'updated_by': userId,
  };

  Map<String, dynamic> toUpdate(String userId) => {
    'name': name,
    'description': description,
    'color_hex': colorHex,
    'status': status,
    'start_date': startDate?.yyyyMmDd,
    'end_date': endDate?.yyyyMmDd,
    'updated_by': userId,
  };
}
