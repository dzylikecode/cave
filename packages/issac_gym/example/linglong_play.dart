import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:issac_gym/issac_gym.dart';
import 'package:torch_dart/torch_dart.dart' as torch;

const defaultPosition = [
  -0.23,
  0.0,
  0.0,
  0.3,
  -0.14,
  0.0,
  -0.23,
  0.0,
  0.0,
  0.3,
  -0.14,
  0.0,
];
const kp = [
  280.0,
  350.0,
  150.0,
  280.0,
  100.0,
  100.0,
  280.0,
  350.0,
  150.0,
  280.0,
  100.0,
  100.0,
];
const kd = [14.0, 14.0, 5.0, 14.0, 5.0, 5.0, 14.0, 14.0, 5.0, 14.0, 5.0, 5.0];
const motorTorque = [
  330.0,
  150.0,
  130.0,
  150.0,
  90.0,
  90.0,
  330.0,
  150.0,
  130.0,
  150.0,
  90.0,
  90.0,
];
const jointNames = [
  'left_hip_pitch',
  'left_hip_roll',
  'left_hip_yaw',
  'left_knee',
  'left_ankle_pitch',
  'left_ankle_roll',
  'right_hip_pitch',
  'right_hip_roll',
  'right_hip_yaw',
  'right_knee',
  'right_ankle_pitch',
  'right_ankle_roll',
];
const dt = 0.002;
const decimation = 10;
double clamp(double v, double limit) => v.clamp(-limit, limit).toDouble();

List<double> commandAt(int step) {
  if (step < 2000) return [0.7, 0, 0];
  if (step < 4000) return [0, 0, 0.5];
  if (step < 6000) return [-0.5, 0, 0];
  if (step < 8000) return [0, 0, -1];
  return [0, 0, 0];
}

// Isaac root quaternion is xyzw; angular velocity is in world coordinates.
List<double> makeObservation(
  List<double> root,
  List<double> q,
  List<double> dq,
  List<int> order,
  List<double> action,
  List<double> command,
  double phase,
) {
  final x = root[3], y = root[4], z = root[5], w = root[6];
  final omega = Vector3(root[10], root[11], root[12]);
  // R(q)^T maps world vectors into the policy's body frame.
  final vx = omega.x, vy = omega.y, vz = omega.z;
  omega.setValues(
    (1 - 2 * (y * y + z * z)) * vx +
        2 * (x * y + w * z) * vy +
        2 * (x * z - w * y) * vz,
    2 * (x * y - w * z) * vx +
        (1 - 2 * (x * x + z * z)) * vy +
        2 * (y * z + w * x) * vz,
    2 * (x * z + w * y) * vx +
        2 * (y * z - w * x) * vy +
        (1 - 2 * (x * x + y * y)) * vz,
  );
  final obs = List<double>.filled(50, 0);
  obs.setRange(3, 6, [command[0] * 2, command[1] * 2, command[2] * 0.25]);
  obs[6] = math.sin(2 * math.pi * phase);
  obs[7] = math.cos(2 * math.pi * phase);
  obs.setRange(8, 11, [omega.x * 0.25, omega.y * 0.25, omega.z * 0.25]);
  obs.setRange(11, 14, [
    2 * (w * y - z * x),
    -2 * (z * y + w * x),
    1 - 2 * (w * w + z * z),
  ]);
  for (var i = 0; i < 12; i++) {
    obs[14 + i] = q[order[i]] - defaultPosition[i];
    obs[26 + i] = dq[order[i]] * 0.05;
    obs[38 + i] = action[i];
  }
  return obs.map((v) => clamp(v, 100)).toList();
}

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption(
      'asset-root',
      defaultsTo: File.fromUri(
        Platform.script.resolve('../assets/LingLong2.0_20260616/'),
      ).path,
    )
    ..addOption(
      'policy',
      defaultsTo: File.fromUri(
        Platform.script.resolve('../assets/models/lite_yuhan.pt'),
      ).path,
    )
    ..addOption('steps', defaultsTo: '0')
    ..addFlag('headless', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(arguments);
  if (args.flag('help')) {
    print(parser.usage);
    return;
  }
  final steps = int.parse(args.option('steps')!);
  final headless = args.flag('headless');
  if (steps < 0 || (headless && steps == 0)) {
    throw ArgumentError('Headless mode requires --steps > 0.');
  }
  final rootPath = args.option('asset-root')!;
  var policyPath = args.option('policy')!;
  final inferencePath = File.fromUri(
    Platform.script.resolve('../assets/models/lite_yuhan_inference.pt'),
  ).path;
  if (!args.wasParsed('policy') && File(inferencePath).existsSync()) {
    policyPath = inferencePath;
  }
  for (final path in ['$rootPath/LingLong2.urdf', policyPath]) {
    if (!File(path).existsSync()) throw ArgumentError('Missing $path');
  }
  // Import Isaac Gym before loading PyTorch.
  final gym = acquire_gym();
  // Loading the original archive can abort PyTorch 1.10 inside native code;
  // a Dart exception handler cannot recover from that failure.
  if (!args.wasParsed('policy') &&
      policyPath != inferencePath &&
      int.parse(torch.Torch.version.split('.').first) < 2) {
    gym.dispose();
    throw StateError(
      'The original lite_yuhan.pt is incompatible with this PyTorch version. '
      'Run tool/export_linglong_policy.py with a newer PyTorch Python '
      'environment to generate assets/models/lite_yuhan_inference.pt.',
    );
  }
  print('Loading policy: $policyPath');
  Sim? sim;
  Viewer? viewer;
  torch.ScriptModule? policy;
  torch.Tensor? roots;
  torch.Tensor? initialRoots;
  try {
    sim = gym.create_sim(
      0,
      headless ? -1 : 0,
      SimType.physx,
      SimParams()
        ..dt = dt
        ..substeps = 1
        ..up_axis = UpAxis.z
        ..gravity = Vector3(0, 0, -9.81)
        ..use_gpu_pipeline = false,
    );
    gym.add_ground(sim, PlaneParams()..normal = Vector3(0, 0, 1));
    final asset = gym.load_asset(
      sim,
      rootPath,
      'LingLong2.urdf',
      AssetOptions()
        ..default_dof_drive_mode = DofDriveMode.effort
        ..collapse_fixed_joints = true
        ..fix_base_link = false,
    );
    final names = gym.get_asset_dof_names(asset);
    final order = jointNames.map(names.indexOf).toList();
    if (names.length != 12 || order.any((i) => i < 0)) {
      throw StateError('Expected LingLong 12 leg joints; got $names');
    }
    final env = gym.create_env(sim, Vector3(-2, -2, 0), Vector3(2, 2, 2), 1);
    final actor = gym.create_actor(
      env,
      asset,
      Transform()..p = Vector3(0, 0, 0.99),
      'linglong',
      0,
      0,
    );
    final props = gym.get_asset_dof_properties(asset);
    try {
      props.setField('stiffness', List.filled(12, 0));
      props.setField('damping', List.filled(12, 0));
      props.setField('driveMode', List.filled(12, 3)); // DOF_MODE_EFFORT
      gym.set_actor_dof_properties(env, actor, props);
    } finally {
      props.dispose();
    }
    void resetDofs() {
      final state = gym.get_actor_dof_states(env, actor, StateFlags.all);
      try {
        final positions = List<double>.filled(12, 0);
        for (var i = 0; i < 12; i++) {
          positions[order[i]] = defaultPosition[i];
        }
        state.setField('pos', positions);
        state.setField('vel', List.filled(12, 0));
        gym.set_actor_dof_states(env, actor, state, StateFlags.all);
      } finally {
        state.dispose();
      }
    }

    resetDofs();
    gym.prepare_sim(sim);
    roots = gym.acquire_actor_root_state_tensor(sim);
    gym.refresh_actor_root_state_tensor(sim);
    initialRoots = roots.clone();
    policy = torch.jit.load(
      policyPath,
      map_location: const torch.Device(torch.DeviceType.cpu),
    )..eval();
    if (!headless) {
      viewer = gym.create_viewer(sim, CameraProperties());
      gym.subscribe_viewer_keyboard_event(viewer, KeyboardInput.escape, 'quit');
      gym.subscribe_viewer_keyboard_event(viewer, KeyboardInput.r, 'reset');
      gym.viewer_camera_look_at(
        viewer,
        env,
        Vector3(3, 2, 1.7),
        Vector3(0, 0, 0.8),
      );
    }
    var action = List<double>.filled(12, 0);
    final filtered = List<double>.filled(12, 0);
    final history = Queue<List<double>>();
    var phase = 0.0;
    var episodeStep = 0;
    for (var step = 0; steps == 0 || step < steps; step++) {
      if (viewer != null) {
        if (gym.query_viewer_has_closed(viewer)) break;
        final events = gym.query_viewer_action_events(viewer);
        if (events.any((e) => e.action == 'quit' && e.value > 0)) break;
        if (events.any((e) => e.action == 'reset' && e.value > 0)) {
          gym.set_actor_root_state_tensor(sim, initialRoots);
          resetDofs();
          action = List.filled(12, 0);
          filtered.fillRange(0, 12, 0);
          history.clear();
          phase = 0;
          episodeStep = 0;
        }
      }
      gym.refresh_actor_root_state_tensor(sim);
      final batch = roots.toList() as List;
      final root = (batch.first as List)
          .map((v) => (v as num).toDouble())
          .toList();
      if (root.any((v) => !v.isFinite)) {
        throw StateError('Nonfinite root state');
      }
      final state = gym.get_actor_dof_states(env, actor, StateFlags.all);
      late List<double> q, dq;
      try {
        q = state.field('pos');
        dq = state.field('vel');
      } finally {
        state.dispose();
      }
      final command = commandAt(episodeStep);
      if (history.isEmpty) {
        final obs = makeObservation(root, q, dq, order, action, [
          0,
          0,
          0,
        ], phase);
        for (var i = 0; i < 21; i++) {
          history.add(List.of(obs));
        }
      }
      if (episodeStep % decimation == 0) {
        phase = (phase + dt * decimation / 0.7) % 1;
        if (command.every((v) => v.abs() < 0.1) && phase < 0.05) phase = 0;
        history.removeFirst();
        history.add(
          makeObservation(root, q, dq, order, action, command, phase),
        );
        final input = torch.tensor([
          history.expand((v) => v).toList(),
        ], dtype: torch.DType.float32);
        try {
          final output = torch.inference_mode(() => policy!(input));
          try {
            final values = ((output.toList() as List).first as List);
            if (values.length != 12 ||
                values.any((v) => !(v as num).isFinite)) {
              throw StateError('Policy must return 12 finite actions');
            }
            action = values
                .map((v) => clamp((v as num).toDouble(), 20))
                .toList();
          } finally {
            output.dispose();
          }
        } finally {
          input.dispose();
        }
      }
      final efforts = List<double>.filled(12, 0);
      for (var i = 0; i < 12; i++) {
        filtered[i] = 0.1 * action[i] + 0.9 * filtered[i];
        var target =
            filtered[i] * 0.5 * motorTorque[i] / kp[i] + defaultPosition[i];
        if (i == 4 || i == 10) target = clamp(target, 0.8);
        if (i == 5 || i == 11) target = clamp(target, 0.4);
        efforts[order[i]] = clamp(
          kp[i] * (target - q[order[i]]) - kd[i] * dq[order[i]],
          100,
        );
      }
      gym.apply_actor_dof_efforts(env, actor, efforts);
      gym.simulate(sim);
      gym.fetch_results(sim, true);
      if (viewer != null && step % 16 == 0) {
        gym.step_graphics(sim);
        gym.draw_viewer(viewer, sim, true);
      }
      if (viewer != null) gym.sync_frame_time(sim);
      episodeStep++;
      if (steps > 0 && step == steps - 1) {
        print('Completed $steps steps; base z=${root[2].toStringAsFixed(3)}');
      }
    }
  } finally {
    initialRoots?.dispose();
    roots?.dispose();
    policy?.dispose();
    if (viewer != null) gym.destroy_viewer(viewer);
    if (sim != null) gym.destroy_sim(sim);
    gym.dispose();
  }
}
