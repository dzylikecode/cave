import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';
import 'package:py_embed/py_embed.dart';
import 'package:torch_dart/torch_dart.dart';

const actionCount = 12;
const historyLength = 21;
const observationSize = 14 + 3 * actionCount;
const dt = 0.002;
const decimation = 10;

const defaultPosition = <double>[
  -0.23,
  0,
  0,
  0.3,
  -0.14,
  0,
  -0.23,
  0,
  0,
  0.3,
  -0.14,
  0,
];
const kp = <double>[280, 350, 150, 280, 100, 100, 280, 350, 150, 280, 100, 100];
const kd = <double>[14, 14, 5, 14, 5, 5, 14, 14, 5, 14, 5, 5];
const motorTorque = <double>[
  330,
  150,
  130,
  150,
  90,
  90,
  330,
  150,
  130,
  150,
  90,
  90,
];

double clamp(double value, double limit) =>
    value.clamp(-limit, limit).toDouble();

List<double> commandAt(int step) {
  if (step < 2000) return [0.7, 0, 0];
  if (step < 4000) return [0, 0, 0.5];
  if (step < 6000) return [-0.5, 0, 0];
  if (step < 8000) return [0, 0, -1.0];
  return [0, 0, 0];
}

List<double> makeObservation(
  MjData data,
  List<double> lastAction,
  List<double> command,
  double phase,
) {
  final obs = List<double>.filled(observationSize, 0);
  obs.setRange(3, 6, [command[0] * 2, command[1] * 2, command[2] * 0.25]);
  obs[6] = math.sin(2 * math.pi * phase);
  obs[7] = math.cos(2 * math.pi * phase);

  final omega = data.sensor('angular-velocity').data;
  for (var i = 0; i < 3; i++) obs[8 + i] = omega[i] * 0.25;

  // MuJoCo sensor quaternion is w, x, y, z. Convert it to projected gravity.
  final quaternion = data.sensor('orientation').data;
  final w = quaternion[0];
  final x = quaternion[1];
  final y = quaternion[2];
  final z = quaternion[3];
  obs[11] = 2 * (-z * x + w * y);
  obs[12] = -2 * (z * y + w * x);
  obs[13] = 1 - 2 * (w * w + z * z);

  final qOffset = data.qpos.length - actionCount;
  final dqOffset = data.qvel.length - actionCount;
  for (var i = 0; i < actionCount; i++) {
    obs[14 + i] = data.qpos[qOffset + i] - defaultPosition[i];
    obs[14 + actionCount + i] = data.qvel[dqOffset + i] * 0.05;
    obs[14 + 2 * actionCount + i] = lastAction[i];
  }
  return obs.map((value) => clamp(value, 100)).toList();
}

void main() {
  final modelPath = File.fromUri(
    Platform.script.resolve('../assets/LingLong2.0_20260616/LingLong2.xml'),
  ).path;
  final policyPath = File.fromUri(
    Platform.script.resolve('../assets/models/lite_yuhan.pt'),
  ).path;

  final model = MjModel.fromXmlPath(modelPath);
  final data = MjData(model);
  final policy = torch.jit.load(policyPath, mapLocation: 'cpu')..eval();
  final viewer = MujocoViewer.launchPassive(model, data);

  var action = List<double>.filled(actionCount, 0);
  var filteredAction = List<double>.filled(actionCount, 0);
  final history = Queue<List<double>>();
  var phase = 0.0;

  try {
    // init
    mjStep(model, data);
    final obs0 = makeObservation(data, action, [0.0, 0.0, 0.0], phase);
    for (var i = 0; i < historyLength; i++) {
      history.addLast(.of(obs0));
    }
    for (var step = 0; viewer.isRunning; step++) {
      mjStep(model, data);
      final command = commandAt(step);

      if (step % decimation == 0) {
        phase = (phase + dt * decimation / 0.7) % 1.0;
        if (command.every((value) => value.abs() < 0.1) && phase < 0.05) {
          phase = 0;
        }

        final obs = makeObservation(data, action, command, phase);
        history.removeFirst();
        history.addLast(obs);

        final input = tensor([
          history.expand((frame) => frame).toList(),
        ], dtype: 'float32');
        final output = torch.inferenceMode(() => policy(input));
        try {
          final batch = output.toList() as List<dynamic>;
          final values = batch.first as List<dynamic>;
          action = .generate(
            values.length,
            (i) => clamp((values[i] as num).toDouble(), 20),
            growable: false,
          );
        } finally {
          input.dispose();
          output.dispose();
        }
      }

      final qOffset = data.qpos.length - actionCount;
      final dqOffset = data.qvel.length - actionCount;
      for (var i = 0; i < actionCount; i++) {
        filteredAction[i] = 0.1 * action[i] + 0.9 * filteredAction[i];
        var target =
            filteredAction[i] * 0.5 * motorTorque[i] / kp[i] +
            defaultPosition[i];
        if (i == 4 || i == 10) target = clamp(target, 0.8);
        if (i == 5 || i == 11) target = clamp(target, 0.4);
        final torque =
            kp[i] * (target - data.qpos[qOffset + i]) -
            kd[i] * data.qvel[dqOffset + i];
        data.ctrl[i] = clamp(torque, 100);
      }

      if (step % 16 == 0) {
        viewer.sync();
      }
    }
  } finally {
    Python.shutdown();
  }
}
