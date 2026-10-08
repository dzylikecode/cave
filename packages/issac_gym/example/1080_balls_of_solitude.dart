// ignore_for_file: file_names
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:issac_gym/issac_gym.dart';

/// Collision filtering demo. Press R in the viewer to restore the initial state.
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('num_envs', defaultsTo: '36')
    ..addFlag('all_collisions', negatable: false)
    ..addFlag('no_collisions', negatable: false)
    ..addFlag('flex', negatable: false)
    ..addFlag('use_gpu', negatable: false)
    ..addFlag('use_gpu_pipeline', negatable: false)
    ..addOption('num_threads', defaultsTo: '0')
    ..addOption('compute_device_id', defaultsTo: '0')
    ..addOption('graphics_device_id', defaultsTo: '0')
    ..addOption(
      'asset_root',
      defaultsTo: File.fromUri(
        Platform.script.resolve('../ref_code/isaacgym/assets'),
      ).path,
    )
    ..addFlag('headless', negatable: false)
    ..addOption(
      'steps',
      defaultsTo: '0',
      help: '0: unlimited; headless requires a positive limit.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args.flag('help')) {
    print(parser.usage);
    return;
  }
  int number(String key) => int.parse(args.option(key)!);
  final numEnvs = number('num_envs');
  final steps = number('steps');
  final headless = args.flag('headless');
  if (numEnvs <= 0 || steps < 0 || (headless && steps == 0)) {
    throw ArgumentError(
      'num_envs must be positive; steps must be nonnegative and positive in headless mode.',
    );
  }
  if (args.flag('all_collisions') && args.flag('no_collisions')) {
    throw ArgumentError('Choose only one collision mode.');
  }
  final assetRoot = args.option('asset_root')!;
  if (!File('$assetRoot/urdf/ball.urdf').existsSync()) {
    throw ArgumentError(
      'Missing $assetRoot/urdf/ball.urdf; supply --asset_root.',
    );
  }
  final params = SimParams()..use_gpu_pipeline = false;
  final type = args.flag('flex') ? SimType.flex : SimType.physx;
  if (type == SimType.flex) {
    params.flex
      ..shape_collision_margin = 0.25
      ..num_outer_iterations = 4
      ..num_inner_iterations = 10;
  } else {
    params.substeps = 1;
    params.physx
      ..solver_type = 1
      ..num_position_iterations = 4
      ..num_velocity_iterations = 1
      ..num_threads = number('num_threads')
      ..use_gpu = args.flag('use_gpu');
  }
  if (args.flag('use_gpu_pipeline')) {
    print('This example uses the CPU pipeline.');
  }
  final gym = acquire_gym();
  Sim? sim;
  Viewer? viewer;
  RigidBodyStates? initialState;
  try {
    sim = gym.create_sim(
      number('compute_device_id'),
      headless ? -1 : number('graphics_device_id'),
      type,
      params,
    );
    gym.add_ground(sim, PlaneParams());
    if (!headless) {
      viewer = gym.create_viewer(sim, CameraProperties());
      gym.subscribe_viewer_keyboard_event(viewer, KeyboardInput.r, 'reset');
    }
    final asset = gym.load_asset(
      sim,
      assetRoot,
      'urdf/ball.urdf',
      AssetOptions(),
    );
    final random = Random(17);
    for (var i = 0; i < numEnvs; i++) {
      final env = gym.create_env(
        sim,
        Vector3(-1.25, 0, -1.25),
        Vector3(1.25, 1.25, 1.25),
        sqrt(numEnvs).floor(),
      );
      final color = Vector3(
        0.5 + 0.5 * random.nextDouble(),
        0.5 + 0.5 * random.nextDouble(),
        0.5 + 0.5 * random.nextDouble(),
      );
      final pose = Transform();
      const spacing = 0.5;
      var minCoord = -0.5 * 3 * spacing;
      var y = minCoord + 4;
      for (var n = 4; n > 0; n--) {
        for (var j = 0; j < n; j++) {
          for (var k = 0; k < n; k++) {
            pose.p = Vector3(
              minCoord + k * spacing,
              1.5 + y,
              minCoord + j * spacing,
            );
            final actor = gym.create_actor(
              env,
              asset,
              pose,
              null,
              args.flag('all_collisions') || args.flag('no_collisions') ? 0 : i,
              args.flag('no_collisions') ? 1 : 0,
            );
            gym.set_rigid_body_color(
              env,
              actor,
              0,
              MeshType.visualAndCollision,
              color,
            );
          }
        }
        y += spacing;
        minCoord = -0.5 * (n - 2) * spacing;
      }
    }
    if (viewer != null) {
      gym.viewer_camera_look_at(
        viewer,
        null,
        Vector3(20, 5, 20),
        Vector3(0, 1, 0),
      );
    }
    final states = gym.get_sim_rigid_body_states(sim, StateFlags.all);
    try {
      initialState = states.copy();
    } finally {
      states.dispose();
    }
    print(
      'Created $numEnvs environments, ${initialState.length} rigid bodies.',
    );
    var frame = 0;
    while ((steps == 0 || frame < steps) &&
        (viewer == null || !gym.query_viewer_has_closed(viewer))) {
      if (viewer != null) {
        for (final event in gym.query_viewer_action_events(viewer)) {
          if (event.action == 'reset' && event.value > 0) {
            if (!gym.set_sim_rigid_body_states(
              sim,
              initialState,
              StateFlags.all,
            )) {
              throw StateError('Failed to restore initial state');
            }
          }
        }
      }
      gym.simulate(sim);
      gym.fetch_results(sim, true);
      if (viewer != null) {
        gym.step_graphics(sim);
        gym.draw_viewer(viewer, sim, true);
        gym.sync_frame_time(sim);
      }
      frame++;
    }
  } finally {
    initialState?.dispose();
    if (viewer != null) gym.destroy_viewer(viewer);
    if (sim != null) gym.destroy_sim(sim);
    gym.dispose();
  }
}
