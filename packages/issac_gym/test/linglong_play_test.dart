import 'dart:math' as math;

import 'package:test/test.dart';

import '../example/linglong_play.dart' as play;

void main() {
  test('observation preserves policy layout and joint name mapping', () {
    final order = List.generate(12, (i) => 11 - i);
    final q = List<double>.filled(12, 0);
    final dq = List<double>.filled(12, 0);
    for (var i = 0; i < 12; i++) {
      q[order[i]] = play.defaultPosition[i] + 0.1;
      dq[order[i]] = 2;
    }
    final obs = play.makeObservation(
      [0, 0, 0.99, 0, 0, 0, 1, 0, 0, 0, 4, 8, 12],
      q,
      dq,
      order,
      List.filled(12, 0.2),
      [0.7, 0, 0.5],
      0.25,
    );
    expect(obs.length, 50);
    expect(obs.take(6), [0, 0, 0, 1.4, 0, 0.125]);
    expect(obs[6], closeTo(1, 1e-12));
    expect(obs.sublist(8, 14), [1, 2, 3, 0, 0, -1]);
    for (final value in obs.sublist(14, 38)) {
      expect(value, closeTo(0.1, 1e-12));
    }
    expect(obs.sublist(38), List.filled(12, 0.2));
  });

  test('world angular velocity is rotated into body frame', () {
    final half = math.sqrt(0.5);
    final obs = play.makeObservation(
      [0, 0, 1, 0, 0, half, half, 0, 0, 0, 1, 0, 0],
      play.defaultPosition,
      List.filled(12, 0),
      List.generate(12, (i) => i),
      List.filled(12, 0),
      [0, 0, 0],
      0,
    );
    expect(obs[8], closeTo(0, 1e-12));
    expect(obs[9], closeTo(-0.25, 1e-7));
    expect(obs[13], closeTo(-1, 1e-12));
  });
}
