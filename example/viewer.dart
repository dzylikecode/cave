import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

void main() async {
  final model = MjModel.from_xml_path(
    'assets/LingLong2.0_20260616/LingLong2_waist.xml',
  );
  final data = MjData(model);
  final viewer = MujocoViewer.launch_passive(model, data);

  // timestep = 0.001，因此16步约等于16 ms仿真时间。
  const stepsPerFrame = 16;

  try {
    for (var i = 0; viewer.is_running; i++) {
      mj_step(model, data);
      
      if (i % stepsPerFrame == 0) {
        viewer.sync();
      }

      // 防止循环完全占满CPU；具体值可调整。
      await Future.delayed(.zero);
    }
  } finally {
    model.dispose();
    data.dispose();
    viewer.dispose();
  }
}
