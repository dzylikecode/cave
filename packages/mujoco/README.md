# mujoco

Dart API for [MuJoCo](https://github.com/google-deepmind/mujoco).

The current implementation uses `py_embed` and the official Python `mujoco`
package. The public Dart API is independent of Python so the internal backend
can later be replaced by a native or WASM implementation.

## Setup

Create and activate a Python environment, then install MuJoCo:

```bash
uv venv --seed
pip install mujoco
```

`py_embed` resolves the active virtual environment automatically.

## Usage

```dart
import 'package:mujoco/mujoco.dart';

void main() {
  final model = MjModel.fromXmlString(modelXml);
  final data = MjData(model);

  try {
    data.qpos[0] = 0.4;
    data.ctrl[0] = 0.1;

    mujoco.forward(model, data);
    mujoco.step(model, data);

    print(data.qpos.toList());
  } finally {
    data.dispose();
    model.dispose();
  }
}
```

`qpos`, `qvel`, `qacc`, and `ctrl` are fixed-length mutable views. Assignments
write directly to the MuJoCo simulation state; call `toList()` to create an
independent Dart snapshot.

## Architecture

```text
MjModel / MjData / MjDoubleArray
                 |
              mujoco
                 |
     MjModelPython / MjDataPython
```

The backend is created lazily by an internal factory. Backend implementation
types are not part of the public package API.
