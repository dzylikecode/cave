import time

import mujoco
import mujoco.viewer


MODEL_XML = """
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
"""


def main() -> None:
    model = mujoco.MjModel.from_xml_string(MODEL_XML)
    data = mujoco.MjData(model)

    with mujoco.viewer.launch_passive(model, data) as viewer:
        while viewer.is_running():
            mujoco.mj_step(model, data)
            viewer.sync()
            time.sleep(0.002)


if __name__ == "__main__":
    main()
