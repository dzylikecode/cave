# issac gym

Dart bindings for Isaac Gym Preview 4.

[article](https://arxiv.org/abs/2108.10470) |
[github](https://github.com/isaac-sim/IsaacGymEnvs) |
[source](https://developer.nvidia.com/isaac-gym)

## Install

Install Isaac Gym into the Python 3.8 environment:

```bash
conda create -n gym python=3.8.20 pip
conda activate gym
pip install -e isaacgym/python
```

>
> [!NOTE]
>
> 运行 python 代码设置环境，而对于 dart 代码不需要
>
> ```bash
> export LD_LIBRARY_PATH="$CONDA_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
> ```
>

## Run

From the repository root, activate the same environment and run:

```bash
conda activate gym
dart run example/1080_balls_of_solitude.dart
```

The example creates 36 environments with 1080 balls. Press **R** to reset,
or close the viewer to exit. Use `--help` to see available options.

## LingLong policy play

From the `cave` workspace root:

```bash
conda activate miniloong-leggedgym
dart run packages/issac_gym/example/linglong_play.dart
```

Press **R** to reset the robot and policy history, **Esc** to exit.
The example loads `assets/LingLong2.0_20260616/LingLong2.urdf` and
`assets/models/lite_yuhan_inference.pt` (if present), otherwise
`assets/models/lite_yuhan.pt`, relative to the example. Assets are local and
ignored by Git. Override paths with `--asset-root` and `--policy`.

For a finite run without a viewer:

```bash
dart run packages/issac_gym/example/linglong_play.dart --headless --steps 10000
```

The policy follows `cave/example/rl.dart`: 50 observation values, 21 history
frames (input `[1, 1050]`), 12 actions, 0.002 s physics timestep, inference every
10 steps, action smoothing, ankle limits, and torque-limited PD control.
Joints are mapped by name rather than relying on the importer order. Isaac Gym
uses xyzw root quaternions and world angular velocities; observations transform
angular velocity into the body frame. The play example uses CPU simulation and
CPU inference. The scheduled commands cover forward motion, turning, backward
motion, and stopping. A policy trained in MuJoCo is not guaranteed to behave
identically in PhysX.

Isaac Gym must import before PyTorch. The binding acquires Gym first and lazily
loads `gymtorch` only when tensor APIs are used. On first use, the SDK builds its
PyTorch extension with the environment's compiler and Ninja. If the default
cache is not writable, choose a writable location:

```bash
export TORCH_EXTENSIONS_DIR=/tmp/robot_gym_torch_extensions
```

## Legged simulation APIs

The binding provides asset DOF/body names and counts, DOF properties and state
arrays, effort control, Z-up/gravity/ground/asset configuration, simulation-domain
actor indices, and `prepare_sim`. Structured `GymArray` fields can be read or
written with `field` / `setField`; `copy` creates an independent snapshot.
Dispose each array after use.

Root, DOF, rigid-body and net-contact-force acquisitions return `torch_dart`
`Tensor` wrappers over simulation memory through `gymtorch.wrap_tensor`.
Refresh buffers before reading. Root/DOF state, effort, position targets and
velocity targets support both full and indexed tensor setters. Indexed setters
require **actor indices in the simulation domain**, supplied as contiguous
`int32` tensors on the simulation device. Retain setter inputs until the physics
step has consumed them. Create every environment and actor before `prepare_sim`.
Dispose tensor wrappers before destroying their simulation; they alias its
memory and must not be used afterward. The play loop copies state to Dart for
readability; a training loop should keep its batched operations in tensors.

These are simulation/control bindings; terrain generation, domain randomization,
rewards, observations for training, and PPO training are not implemented here.

## Validation

```bash
dart analyze packages/issac_gym
dart test packages/issac_gym/test/linglong_play_test.dart
ISAAC_GYM_TEST=1 dart test packages/issac_gym/integration_test/legged_tensor_test.dart
```

The integration test needs the local LingLong assets and Isaac Gym Python
environment. It exercises real DOF state copies, tensor layouts, torque setters,
contact refresh, and indexed root/DOF resets. The observation tests check policy
layout, joint mapping, projected gravity and world-to-body angular velocity.

### PyTorch 1.10 compatibility

The original `lite_yuhan.pt` crashes during `torch.jit.load` on the tested
PyTorch 1.10.0+cu113 environment (`Expected Tuple but got String`). This also
reproduces in pure Python. Export a frozen inference graph using an environment
that can load the original model:

```bash
conda run -n miniloong-leggedgym python packages/issac_gym/tool/export_linglong_policy.py
conda activate py_embed
dart run packages/issac_gym/example/linglong_play.dart
```

The exporter leaves the original intact, writes `lite_yuhan_inference.pt`, and
checks that outputs match for zero and random observation histories. The player
prefers this frozen file by default; an explicit `--policy` always overrides
that choice. The export still uses TorchScript and does not require changing the
Isaac Gym environment's installed PyTorch. Both model files live under the
Git-ignored assets directory, so repeat the export on a new checkout.

For the Dart ANYmal C flat task, see `robot_engine/apps/legged_gym` in the sibling
workspace. The bindings also expose per-actor friction and rigid-body masses
(for task-side domain randomization), extended PhysX contact/buffer settings,
and asset maximum linear/angular velocities. These remain simulator primitives;
reward, observation, command and episode logic belongs to the Dart task.
