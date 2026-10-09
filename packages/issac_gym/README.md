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
