# issac gym

[article](https://arxiv.org/abs/2108.10470) |
[github](https://github.com/isaac-sim/IsaacGymEnvs) |
[source](https://developer.nvidia.com/isaac-gym)

Dart bindings for the bundled Isaac Gym Preview 4 SDK. The first API subset
supports `1080_balls_of_solitude`: simulation setup, collision groups and masks,
viewer events, rendering, and rigid-body state snapshots.

## Run the example

Use a Python environment compatible with the bundled SDK (the Linux reference
contains Python 3.6–3.8 extensions). `py_embed` discovers `python` through `PATH`.
Isaac Gym must be imported before PyTorch. The commands below use the existing
local Python 3.8 environment; substitute your environment as needed.

From the repository root:

```bash
conda activate py_embed
export PYTHONPATH="$PWD/packages/issac_gym/ref_code/isaacgym/python${PYTHONPATH:+:$PYTHONPATH}"
export LD_LIBRARY_PATH="$CONDA_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
dart run packages/issac_gym/example/1080_balls_of_solitude.dart
```

By default, 36 environments contain 30 balls each. Press **R** to reset, or close
the viewer to exit. The simulation uses the CPU pipeline, as in the reference.
Colors use Dart's seeded random generator, so they differ from NumPy's sequence.

- `--all_collisions`: allow collisions across environments.
- `--no_collisions`: disable ball-to-ball collisions; the ground still collides.
- `--num_envs 4`: use a smaller scene.
- `--steps 120`: stop after a fixed number of frames.
- `--headless --steps 120`: run without a viewer.
- `--use_gpu` or `--flex`: select GPU PhysX or Flex respectively.
- `--asset_root /path/to/assets`: override the bundled asset location.
- `--help`: list all options.

## API and ownership

Method names and positional arguments follow `gymapi`. Configuration objects
such as `SimParams` and `Transform` are Dart values, converted when passed to Gym;
null configuration fields preserve SDK defaults. Configuration classes currently
expose only the fields required by this example.

`create_sim`, `create_viewer`, and `load_asset` throw if the SDK returns `None`.
Actors are integer handles scoped to their environment. Destroy viewers and
simulations through `gym.destroy_viewer` and `gym.destroy_sim`, then call
`gym.dispose()`. Destroying a simulation also releases its remaining viewers and
invalidates its assets, environments, and borrowed state arrays.

`get_sim_rigid_body_states` returns an opaque state array. Call `copy()` for an
independent reset snapshot, then pass that snapshot to
`set_sim_rigid_body_states`. Dispose both arrays when finished. The snapshot can
outlive the simulation. General NumPy indexing and Tensor APIs are not included.

## Integration test

With the environment above, run:

```bash
cd packages/issac_gym
ISAAC_GYM_TEST=1 dart test test/isaac_gym_integration_test.dart
```

This uses the real SDK to check simulation, independent snapshots, state reset,
and resource lifetimes. Without `ISAAC_GYM_TEST=1`, the test is skipped.
