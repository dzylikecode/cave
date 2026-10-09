// ignore_for_file: implementation_imports
import 'dart:io';

import 'package:issac_gym/issac_gym.dart';
import 'package:issac_gym/src/backend/python.dart';
import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

bool sameStates(RigidBodyStates left, RigidBodyStates right) =>
    Py.using((scope) {
      final a = (left as RigidBodyStatesPython).handle;
      final b = (right as RigidBodyStatesPython).handle;
      final np = scope(PyModule('numpy'));
      final fn = scope(np.getAttr('array_equal'));
      return scope(fn.forward([a, b])).asBool();
    });

void main() {
  test(
    'real SDK: simulate, copy, reset and release state buffers',
    () {
      final gym = acquire_gym();
      final sim = gym.create_sim(
        0,
        -1,
        SimType.physx,
        SimParams()..use_gpu_pipeline = false,
      );
      RigidBodyStates? snapshot;
      var simDestroyed = false;
      try {
        gym.add_ground(sim, PlaneParams());
        final root = Directory('ref_code/isaacgym/assets').absolute.path;
        final asset = gym.load_asset(
          sim,
          root,
          'urdf/ball.urdf',
          AssetOptions(),
        );
        final env = gym.create_env(
          sim,
          Vector3(-1, 0, -1),
          Vector3(1, 1, 1),
          1,
        );
        gym.create_actor(
          env,
          asset,
          Transform()..p = Vector3(0, 5, 0),
          null,
          0,
          0,
        );
        final original = gym.get_sim_rigid_body_states(sim, StateFlags.all);
        expect(original.length, 1);
        snapshot = original.copy();
        original.dispose();
        for (var i = 0; i < 10; i++) {
          gym.simulate(sim);
          gym.fetch_results(sim, true);
        }
        final moved = gym.get_sim_rigid_body_states(sim, StateFlags.all);
        try {
          expect(sameStates(snapshot, moved), isFalse);
        } finally {
          moved.dispose();
        }
        expect(
          gym.set_sim_rigid_body_states(sim, snapshot, StateFlags.all),
          isTrue,
        );
        final reset = gym.get_sim_rigid_body_states(sim, StateFlags.all);
        try {
          expect(sameStates(snapshot, reset), isTrue);
        } finally {
          reset.dispose();
        }
        gym.destroy_sim(sim);
        simDestroyed = true;
        expect(
          snapshot.length,
          1,
        ); // The independent copy outlives the simulation.
      } finally {
        snapshot?.dispose();
        if (!simDestroyed) gym.destroy_sim(sim);
        gym.dispose();
      }
    },
    skip: Platform.environment['ISAAC_GYM_TEST'] != '1'
        ? 'Set ISAAC_GYM_TEST=1 with the Isaac Gym Python 3.8 environment.'
        : false,
  );
}
