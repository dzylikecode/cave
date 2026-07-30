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

`py_embed` resolves the active virtual environment automatically. A specific
Python executable can also be selected before the first MuJoCo call:

```dart
import 'package:py_embed/py_embed.dart';

void main() {
  Python.configure(executable: r'C:\path\to\.venv\Scripts\python.exe');
}
```

## Usage

```dart
import 'package:mujoco/mujoco.dart';

void main() {
  final model = MjModel.fromXmlString(modelXml);
  final data = MjData(model);

  try {
    data.qpos[0] = 0.4;
    data.ctrl[0] = 0.1;

    mjForward(model, data);
    mjStep(model, data);

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
          MujocoBackend
                 |
       PythonMujocoBackend
```

The backend is created lazily by an internal factory. Backend implementation
types are not part of the public package API.
