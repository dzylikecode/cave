import 'dart:io';

import 'package:issac_gym/issac_gym.dart';
import 'package:test/test.dart';
import 'package:torch_dart/torch_dart.dart' as torch;

void main() {
  test(
    'LingLong DOF control, tensor refresh and indexed reset',
    () {
      final gym = acquire_gym();
      final sim = gym.create_sim(
        0,
        -1,
        SimType.physx,
        SimParams()
          ..dt = 0.002
          ..up_axis = UpAxis.z
          ..gravity = Vector3(0, 0, -9.81)
          ..use_gpu_pipeline = false,
      );
      final tensors = <torch.Tensor>[];
      T own<T extends torch.Tensor>(T value) {
        tensors.add(value);
        return value;
      }

      try {
        gym.add_ground(sim, PlaneParams()..normal = Vector3(0, 0, 1));
        final asset = gym.load_asset(
          sim,
          (Directory('assets/LingLong2.0_20260616').existsSync()
                  ? Directory('assets/LingLong2.0_20260616')
                  : Directory('packages/issac_gym/assets/LingLong2.0_20260616'))
              .absolute
              .path,
          'LingLong2.urdf',
          AssetOptions()..default_dof_drive_mode = DofDriveMode.effort,
        );
        expect(gym.get_asset_dof_count(asset), 12);
        expect(gym.get_asset_dof_names(asset), contains('left_knee'));
        final env = gym.create_env(
          sim,
          Vector3(-2, -2, 0),
          Vector3(2, 2, 2),
          1,
        );
        final actor = gym.create_actor(
          env,
          asset,
          Transform()..p = Vector3(0, 0, 1.2),
          'test',
          0,
          0,
        );
        final states = gym.get_actor_dof_states(env, actor, StateFlags.all);
        try {
          states.setField('pos', List.filled(12, 0.1));
          states.setField('vel', List.filled(12, 0));
          expect(
            gym.set_actor_dof_states(env, actor, states, StateFlags.all),
            isTrue,
          );
          final copy = states.copy();
          try {
            states.setField('pos', List.filled(12, 0.2));
            expect(copy.field('pos').first, closeTo(0.1, 1e-6));
            expect(() => copy.setField('pos', [0]), throwsArgumentError);
          } finally {
            copy.dispose();
          }
        } finally {
          states.dispose();
        }
        gym.prepare_sim(sim);
        final roots = own(gym.acquire_actor_root_state_tensor(sim));
        final dofs = own(gym.acquire_dof_state_tensor(sim));
        final bodies = own(gym.acquire_rigid_body_state_tensor(sim));
        final contacts = own(gym.acquire_net_contact_force_tensor(sim));
        gym.refresh_actor_root_state_tensor(sim);
        gym.refresh_dof_state_tensor(sim);
        final initial = own(roots.clone());
        final initialDofs = own(dofs.clone());
        expect(roots.shape, [1, 13]);
        expect(dofs.shape, [12, 2]);
        expect(bodies.shape.last, 13);
        expect(contacts.shape.last, 3);
        final forces = own(torch.zeros([12], dtype: torch.DType.float32));
        final ids = own(
          torch.tensor([
            gym.get_actor_index(env, actor, IndexDomain.sim),
          ], dtype: torch.DType.int32),
        );
        expect(gym.set_dof_actuation_force_tensor(sim, forces), isTrue);
        expect(
          gym.set_dof_actuation_force_tensor_indexed(sim, forces, ids, 1),
          isTrue,
        );
        for (var i = 0; i < 10; i++) {
          gym.simulate(sim);
          gym.fetch_results(sim, true);
        }
        gym.refresh_actor_root_state_tensor(sim);
        gym.refresh_rigid_body_state_tensor(sim);
        gym.refresh_net_contact_force_tensor(sim);
        expect(
          ((roots.toList() as List).first as List)[2] as num,
          lessThan(1.2),
        );
        expect(
          gym.set_actor_root_state_tensor_indexed(sim, initial, ids, 1),
          isTrue,
        );
        expect(
          gym.set_dof_state_tensor_indexed(sim, initialDofs, ids, 1),
          isTrue,
        );
        gym.refresh_actor_root_state_tensor(sim);
        expect(
          ((roots.toList() as List).first as List)[2] as num,
          closeTo(1.2, 1e-4),
        );
      } finally {
        for (final tensor in tensors.reversed) {
          tensor.dispose();
        }
        gym.destroy_sim(sim);
        gym.dispose();
      }
    },
    skip: Platform.environment['ISAAC_GYM_TEST'] != '1'
        ? 'Set ISAAC_GYM_TEST=1 with an Isaac Gym Python environment.'
        : false,
  );
}
