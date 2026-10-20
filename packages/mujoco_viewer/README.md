# mujoco_viewer

Wraps Python `mujoco.viewer.launch_passive` using the public Dart MuJoCo API.
Activate a Python environment with `mujoco` installed before running Dart.
`py_embed` discovers `python` on PATH. A working desktop display is required.
Linux Python MuJoCo 3.2.3 has been exercised in this workspace.

```dart
import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

Future<void> main() async {
  final model = MjModel.from_xml_path('robot.xml');
  final data = MjData(model);
  MujocoViewer? viewer;
  try {
    final display = MujocoViewer.launch_passive(model, data);
    viewer = display;
    while (display.is_running) {
      display.withLock(() {
        // Update ctrl and advance physics with exclusive model/data access.
        mj_step(model, data);
      });
      display.sync(); // Sync outside the lock.
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  } finally {
    viewer?.dispose();
    data.dispose();
    model.dispose();
  }
}
```

The passive viewer never advances physics; Dart owns the simulation loop.
`withLock` accepts synchronous work only. `dispose()` closes the window and
releases its handle idempotently, without disposing model/data. Always dispose
the viewer before its model and data. The Python implementation narrows model/data parameters with `covariant`.
Dart rejects incompatible backend types with `TypeError` before entering the implementation.

```sh
# Run from this package directory with the Python environment active:
dart test --concurrency=1
```

Tests use a deterministic Python window handle for lifecycle/lock assertions;
actual desktop opening, synchronization and closure are verified through the
LingLong `--viewer` smoke run.
