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

void main() async {
  print('MuJoCo version: ${Mujoco.version}');

  final model = MjModel.from_xml_string(modelXml);
  final data = MjData(model);
  MujocoViewer? viewer;
  try {
    final display = MujocoViewer.launch_passive(model, data);
    viewer = display;
    while (display.is_running) {
      display.withLock(() => mj_step(model, data));
      display.sync();
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  } finally {
    viewer?.dispose();
    data.dispose();
    model.dispose();
  }
}
