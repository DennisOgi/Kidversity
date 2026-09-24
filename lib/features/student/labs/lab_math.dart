import 'dart:math' as math;

double pendulumPeriod(double lengthMetres, double gravity) {
  if (lengthMetres <= 0 || gravity <= 0) return 0;
  return 2 * math.pi * math.sqrt(lengthMetres / gravity);
}

class SnellResult {
  final double? refractionDegrees;
  final bool reflectsInside;

  const SnellResult({this.refractionDegrees, required this.reflectsInside});
}

/// A ray leaving glass for air. [incidenceDegrees] is measured from the normal.
/// Above the critical angle the ray stays in the glass.
SnellResult snellGlassToAir(double incidenceDegrees, double refractiveIndex) {
  final i = incidenceDegrees * math.pi / 180;
  final sine = math.sin(i) * refractiveIndex;
  if (sine.abs() > 1 || refractiveIndex <= 0) {
    return const SnellResult(reflectsInside: true);
  }
  return SnellResult(
    refractionDegrees: math.asin(sine) * 180 / math.pi,
    reflectsInside: false,
  );
}

/// Air into glass. [incidenceDegrees] is measured from the normal.
SnellResult snellIntoGlass(double incidenceDegrees, double refractiveIndex) {
  final i = incidenceDegrees * math.pi / 180;
  final sine = math.sin(i) / refractiveIndex;
  if (sine.abs() > 1) {
    return const SnellResult(reflectsInside: true);
  }
  return SnellResult(
    refractionDegrees: math.asin(sine) * 180 / math.pi,
    reflectsInside: false,
  );
}

double gasPressure({
  required double amount,
  required double temperatureKelvin,
  required double volumeLitres,
}) {
  if (volumeLitres <= 0) return 0;
  return amount * temperatureKelvin / volumeLitres;
}

double seriesCurrent(double voltage, double r1, double r2) {
  final total = r1 + r2;
  if (total <= 0) return 0;
  return voltage / total;
}

double parallelCurrent(double voltage, double r1, double r2) {
  if (r1 <= 0 || r2 <= 0) return 0;
  return voltage / r1 + voltage / r2;
}

double moment(double massGrams, double distanceCm) => massGrams * distanceCm;

bool momentsBalanced(
  double leftMass,
  double leftCm,
  double rightMass,
  double rightCm,
) => (moment(leftMass, leftCm) - moment(rightMass, rightCm)).abs() < 8;

/// Populations ease toward a teaching target. This is a simplified web,
/// not a full ecosystem model.
({double grass, double hopper, double frog, double hawk}) foodWebTarget({
  required bool grass,
  required bool hopper,
  required bool frog,
  required bool hawk,
}) {
  if (!grass) return (grass: 0.02, hopper: 0.04, frog: 0.04, hawk: 0.03);
  if (!hopper) return (grass: 0.92, hopper: 0.02, frog: 0.05, hawk: 0.04);
  if (!frog && !hawk) {
    return (grass: 0.38, hopper: 0.82, frog: 0.02, hawk: 0.02);
  }
  if (!frog) return (grass: 0.34, hopper: 0.74, frog: 0.02, hawk: 0.08);
  if (!hawk) return (grass: 0.8, hopper: 0.22, frog: 0.58, hawk: 0.02);
  return (grass: 0.62, hopper: 0.4, frog: 0.28, hawk: 0.2);
}

enum BillStop { assembly, president, court, law }

BillStop billOutcome({
  required bool assemblyPasses,
  required bool presidentSigns,
  required bool courtUpholds,
}) {
  if (!assemblyPasses) return BillStop.assembly;
  if (!presidentSigns) return BillStop.president;
  return courtUpholds ? BillStop.law : BillStop.court;
}

({double slope, double intercept}) leastSquares(
  List<(double x, double y)> points,
) {
  if (points.length < 2) return (slope: 0, intercept: 0);
  final n = points.length.toDouble();
  var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
  for (final point in points) {
    sumX += point.$1;
    sumY += point.$2;
    sumXY += point.$1 * point.$2;
    sumXX += point.$1 * point.$1;
  }
  final denom = n * sumXX - sumX * sumX;
  if (denom == 0) return (slope: 0, intercept: sumY / n);
  final slope = (n * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / n;
  return (slope: slope, intercept: intercept);
}

double meanAbsoluteResidual(
  List<(double x, double y)> points,
  double slope,
  double intercept,
) {
  if (points.isEmpty) return 0;
  var total = 0.0;
  for (final point in points) {
    total += (point.$2 - (slope * point.$1 + intercept)).abs();
  }
  return total / points.length;
}

/// Image distance for a thin convex lens. Null when the object sits on the focus.
double? lensImageDistance(double objectCm, double focalCm) {
  if (focalCm <= 0 || objectCm <= 0) return null;
  if ((objectCm - focalCm).abs() < 0.05) return null;
  return objectCm * focalCm / (objectCm - focalCm);
}

double hookeForce(double stiffnessPerCm, double extensionCm) =>
    stiffnessPerCm * extensionCm;

double acceleration(double forceNewtons, double massKg) {
  if (massKg <= 0) return 0;
  return forceNewtons / massKg;
}

String matterState(double celsius) {
  if (celsius < 0) return 'solid';
  if (celsius < 100) return 'liquid';
  return 'gas';
}

double reactionRate({required double concentration, required double celsius}) {
  final warmth = (1 + (celsius - 20) / 25).clamp(0.2, 4.0);
  return concentration.clamp(0, 2) * warmth;
}

double enzymeActivity(double celsius) {
  if (celsius >= 70) return 0;
  final width = celsius <= 37 ? 16.0 : 8.0;
  return math
      .exp(-math.pow(celsius - 37, 2) / (2 * width * width))
      .clamp(0, 1)
      .toDouble();
}

double photosynthesisRate(double light, double carbonDioxide) => math.min(
  light.clamp(0, 1).toDouble(),
  carbonDioxide.clamp(0, 1).toDouble(),
);

/// School shell model: 2, then 8, then 8, then 2. Stops at calcium.
List<int> electronShells(int atomicNumber) {
  const caps = [2, 8, 8, 2];
  final shells = <int>[];
  var left = atomicNumber.clamp(0, 20);
  for (final cap in caps) {
    if (left <= 0) break;
    final taken = left < cap ? left : cap;
    shells.add(taken);
    left -= taken;
  }
  return shells;
}

double hypotenuse(double a, double b) => math.sqrt(a * a + b * b);

bool rainFalling(double heat) => heat >= 0.62;

const governmentDuties = <String, String>{
  'defence': 'Federal',
  'currency': 'Federal',
  'markets': 'Local',
  'refuse': 'Local',
};

String? governmentLevel(String duty) => governmentDuties[duty];

String vernierReadingSentence(double millimetres) {
  final clamped = (millimetres * 10).round() / 10;
  final main = clamped.floor();
  final tenth = ((clamped - main) * 10).round();
  return 'The zero sits just past $main mm. Vernier line $tenth meets a main line, so the reading is ${clamped.toStringAsFixed(1)} mm.';
}
