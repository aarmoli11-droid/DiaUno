/// Reglas deterministas del jardín: la animación nunca altera los datos.
class GardenRules {
  const GardenRules._();

  static String flowerForPoints(int points) => switch (points) {
    >= 400 => 'orchid',
    >= 250 => 'sunflower',
    >= 120 => 'tulip',
    >= 40 => 'daisy',
    _ => 'sprout',
  };

  static String flowerLabel(String flower) => switch (flower) {
    'orchid' => 'Orquídea',
    'sunflower' => 'Girasol',
    'tulip' => 'Tulipán',
    'daisy' => 'Margarita',
    _ => 'Brote',
  };

  static int treeStage(int progressPercent) => switch (progressPercent) {
    >= 80 => 4,
    >= 55 => 3,
    >= 25 => 2,
    >= 1 => 1,
    _ => 0,
  };

  static String stageLabel(int stage) => switch (stage) {
    4 => 'Frondoso',
    3 => 'Crecido',
    2 => 'Joven',
    1 => 'Brote',
    _ => 'Semilla',
  };
}

class GardenEvent {
  const GardenEvent({
    required this.id,
    required this.projectId,
    required this.points,
    required this.flowerType,
    required this.eventType,
    required this.createdAt,
    this.projectName,
  });

  final String id;
  final String? projectId;
  final int points;
  final String? flowerType;
  final String eventType;
  final DateTime createdAt;
  final String? projectName;

  factory GardenEvent.fromMap(Map<String, dynamic> map) => GardenEvent(
    id: map['id'] as String,
    projectId: map['project_id'] as String?,
    points: (map['points'] as num).toInt(),
    flowerType: map['flower_type'] as String?,
    eventType: map['event_type'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    projectName: map['name'] as String?,
  );
}
