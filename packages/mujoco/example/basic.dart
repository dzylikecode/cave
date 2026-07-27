import 'package:py_embed/py_embed.dart';
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


void main() async {
  final py = Python.venv(await getPyExecutableFromShell());
  print('mujoco version: ${Mujoco.version}');
  final model = MjModel.fromXmlString(MODEL_XML);
  final data = MjData(model);
  mjForward(model, data);
  print('model: ${model.nq}, ${model.nv}, ${model.nu}');
  print('data: ${data.time}, ${data.qpos}, ${data.qvel}');
  py.dispose();
}