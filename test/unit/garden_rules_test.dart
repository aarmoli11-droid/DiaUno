import 'package:flutter_test/flutter_test.dart';
import 'package:diauno/features/garden/domain/garden.dart';

void main() {
  test('la flor es determinista para un mismo número de puntos', () {
    expect(GardenRules.flowerForPoints(0), 'sprout');
    expect(GardenRules.flowerForPoints(40), 'daisy');
    expect(GardenRules.flowerForPoints(120), 'tulip');
    expect(GardenRules.flowerForPoints(250), 'sunflower');
    expect(GardenRules.flowerForPoints(400), 'orchid');
  });

  test('la etapa del árbol sigue el progreso real', () {
    expect(GardenRules.treeStage(0), 0);
    expect(GardenRules.treeStage(24), 1);
    expect(GardenRules.treeStage(25), 2);
    expect(GardenRules.treeStage(55), 3);
    expect(GardenRules.treeStage(80), 4);
  });
}
