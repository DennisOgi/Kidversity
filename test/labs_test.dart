import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/features/student/labs/lab_catalog.dart';
import 'package:kidversity/features/student/labs/lab_math.dart';
import 'package:kidversity/features/student/labs/physics_labs.dart';
import 'package:kidversity/features/student/labs/practical_labs.dart';

void main() {
  test('pendulum period follows length and gravity', () {
    final period = pendulumPeriod(1, 9.8);
    expect(period, closeTo(2.007, 0.01));
    expect(pendulumPeriod(4, 9.8), closeTo(period * 2, 0.02));
    expect(pendulumPeriod(0, 9.8), 0);
  });

  test('a ray leaving glass reflects past the critical angle', () {
    final through = snellGlassToAir(30, 1.5);
    expect(through.reflectsInside, isFalse);
    expect(through.refractionDegrees!, greaterThan(30));

    final trapped = snellGlassToAir(50, 1.5);
    expect(trapped.reflectsInside, isTrue);

    expect(snellIntoGlass(70, 1.5).reflectsInside, isFalse);
  });

  test('halving the volume doubles the pressure', () {
    final wide = gasPressure(
      amount: 0.08,
      temperatureKelvin: 300,
      volumeLitres: 1.2,
    );
    final tight = gasPressure(
      amount: 0.08,
      temperatureKelvin: 300,
      volumeLitres: 0.6,
    );
    expect(tight, closeTo(wide * 2, 0.001));
  });

  test('parallel bulbs draw more current than the same bulbs in series', () {
    expect(seriesCurrent(6, 8, 12), closeTo(0.3, 0.001));
    expect(parallelCurrent(6, 8, 12), greaterThan(seriesCurrent(6, 8, 12)));
  });

  test('moments balance when the products match', () {
    expect(momentsBalanced(200, 40, 160, 50), isTrue);
    expect(momentsBalanced(200, 30, 150, 40), isTrue);
    expect(momentsBalanced(200, 40, 150, 40), isFalse);
  });

  test('food web collapses without grass and frogs rise without hawks', () {
    final bare = foodWebTarget(
      grass: false,
      hopper: true,
      frog: true,
      hawk: true,
    );
    expect(bare.hopper, lessThan(0.1));
    final safe = foodWebTarget(
      grass: true,
      hopper: true,
      frog: true,
      hawk: false,
    );
    expect(safe.frog, greaterThan(0.5));
  });

  test('a bill stops at the first failed decision', () {
    expect(
      billOutcome(
        assemblyPasses: false,
        presidentSigns: true,
        courtUpholds: true,
      ),
      BillStop.assembly,
    );
    expect(
      billOutcome(
        assemblyPasses: true,
        presidentSigns: false,
        courtUpholds: true,
      ),
      BillStop.president,
    );
    expect(
      billOutcome(
        assemblyPasses: true,
        presidentSigns: true,
        courtUpholds: false,
      ),
      BillStop.court,
    );
    expect(
      billOutcome(
        assemblyPasses: true,
        presidentSigns: true,
        courtUpholds: true,
      ),
      BillStop.law,
    );
  });

  test('school models stay consistent', () {
    expect(lensImageDistance(30, 15), closeTo(30, 0.001));
    expect(lensImageDistance(10, 15)!, isNegative);
    expect(lensImageDistance(15, 15), isNull);
    expect(hookeForce(4, 2.5), closeTo(10, 0.001));
    expect(acceleration(12, 6), closeTo(2, 0.001));
    expect(matterState(-5), 'solid');
    expect(matterState(20), 'liquid');
    expect(matterState(100), 'gas');
    expect(enzymeActivity(37), greaterThan(enzymeActivity(60)));
    expect(photosynthesisRate(0.9, 0.3), closeTo(0.3, 0.001));
    expect(electronShells(10), [2, 8]);
    expect(electronShells(11), [2, 8, 1]);
    expect(hypotenuse(3, 4), closeTo(5, 0.001));
    expect(rainFalling(0.2), isFalse);
    expect(rainFalling(0.7), isTrue);
    expect(governmentLevel('defence'), 'Federal');
    expect(governmentLevel('refuse'), 'Local');
  });

  test('vernier sentence names the tenth', () {
    expect(
      vernierReadingSentence(12.6),
      'The zero sits just past 12 mm. Vernier line 6 meets a main line, so the reading is 12.6 mm.',
    );
  });

  test('a perfect line is recovered by least squares', () {
    final points = <(double, double)>[(1, 3), (2, 5), (3, 7), (4, 9)];
    final fit = leastSquares(points);
    expect(fit.slope, closeTo(2, 0.001));
    expect(fit.intercept, closeTo(1, 0.001));
    expect(
      meanAbsoluteResidual(points, fit.slope, fit.intercept),
      closeTo(0, 0.001),
    );
  });

  test('the bench covers the school subjects', () {
    expect(labCatalog, hasLength(24));
    expect(labCatalog.map((lab) => lab.id).toSet(), hasLength(24));
    expect(labSubjects, [
      'Physics',
      'Chemistry',
      'Biology',
      'Maths',
      'Geography',
      'Government',
    ]);
    for (final lab in labCatalog) {
      expect(lab.idea.trim(), isNotEmpty);
      expect(lab.how.trim(), isNotEmpty);
      expect(lab.challenge.trim(), isNotEmpty);
      expect(labById(lab.id), same(lab));
    }
    expect(labById('missing'), isNull);
  });

  testWidgets('the ray box explains the idea before the stage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: RayLab())),
      ),
    );
    expect(find.text('Ray box'), findsOneWidget);
    expect(find.textContaining('total internal reflection'), findsOneWidget);
    expect(find.textContaining('Find an angle'), findsOneWidget);
  });

  testWidgets('vernier callipers start away from the challenge reading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: VernierLab())),
      ),
    );
    expect(find.textContaining('12.0 mm'), findsWidgets);
    expect(find.textContaining('Done.'), findsNothing);
  });
}
