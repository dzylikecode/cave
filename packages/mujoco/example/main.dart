import 'package:mujoco/mujoco.dart';

const MODEL_XML = """
<mujoco model="basic_pendulum">
  <option timestep="0.002" gravity="0 0 -9.81"/>

  <worldbody>
    <geom name="floor" type="plane" size="2 2 0.1"/>

    <body name="pendulum" pos="0 0 1">
      <joint
        name="hinge"
        type="hinge"
        axis="0 1 0"
        damping="0.05"
      />
      <geom
        name="pole"
        type="capsule"
        fromto="0 0 0 0 0 -0.8"
        size="0.04"
        mass="1"
      />
    </body>
  </worldbody>

  <actuator>
    <motor name="hinge_motor" joint="hinge" gear="1"/>
  </actuator>
</mujoco>
""";

void main() {
  print('mujoco version: ${mujoco.version}');
  final model = MjModel.fromXmlString(MODEL_XML);
  final data = MjData(model);
  data.qpos[0] = 0.4;
  mjForward(model, data);

  print('model: ${model.nq}, ${model.nv}, ${model.nu}');
  print('data: ${data.time}, ${data.qpos.toList()}, ${data.qvel.toList()}');

  data.ctrl[0] = 0.1;
  for (var step = 0; step < 1000; step++) {
    mjStep(model, data);
    if (step % 100 == 0) {
      print('step: $step, time: ${data.time}, qpos: ${data.qpos.toList()}');
    }
  }
  print('final: ${data.time}, ${data.qpos.toList()}');
}
