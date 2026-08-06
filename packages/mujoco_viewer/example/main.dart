import 'dart:io';

import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

const modelXml = '''
<mujoco model="pendulum">
  <option timestep="0.002"/>
  <worldbody>
    <geom type="plane" size="2 2 0.1"/>
    <body pos="0 0 1">
      <joint type="hinge" axis="0 1 0"/>
      <geom type="capsule" fromto="0 0 0 0 0 -0.8" size="0.04"/>
    </body>
  </worldbody>
</mujoco>
''';

void main() {
  print('MuJoCo version: ${mujoco.version}');

  final model = MjModel.fromXmlString(modelXml);
  final data = MjData(model);
  final viewer = MujocoViewer.launchPassive(model, data);

  try {
    while (viewer.isRunning) {
      mjStep(model, data);
      viewer.sync();
      sleep(const Duration(milliseconds: 2));
    }
  } finally {
    viewer.dispose();
  }
}
