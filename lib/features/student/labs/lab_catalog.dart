import 'lab_frame.dart';
import 'concept_labs.dart';
import 'physics_labs.dart';
import 'practical_labs.dart';
import 'school_labs.dart';

const labCatalog = <LabSpec>[
  pendulumSpec,
  waveSpec,
  raySpec,
  lensSpec,
  momentsSpec,
  hookeSpec,
  forceSpec,
  pistonSpec,
  circuitSpec,
  vernierSpec,
  bestFitSpec,
  buretteSpec,
  statesSpec,
  rateSpec,
  atomSpec,
  osmosisSpec,
  enzymeSpec,
  photosynthesisSpec,
  foodWebSpec,
  pythagorasSpec,
  chanceSpec,
  waterSpec,
  billSpec,
  federalSpec,
];

LabSpec? labById(String id) {
  for (final lab in labCatalog) {
    if (lab.id == id) return lab;
  }
  return null;
}

List<String> get labSubjects {
  final seen = <String>[];
  for (final lab in labCatalog) {
    if (!seen.contains(lab.subject)) seen.add(lab.subject);
  }
  return seen;
}
