# mujoco_viewer

Interactive viewer support for the Dart `mujoco` package.

The current implementation wraps `mujoco.viewer.launch_passive` and therefore
requires the Python backend and a Python environment with `mujoco` installed.

## Usage

```dart
final model = MjModel.fromXmlString(xml);
final data = MjData(model);
final viewer = MujocoViewer.launchPassive(model, data);

try {
  while (viewer.isRunning) {
    mjStep(model, data);
    viewer.sync();
  }
} finally {
  viewer.dispose();
}
```

The passive viewer does not advance simulation state itself. The Dart program
owns the simulation loop and must call `sync()` after changing `MjModel` or
`MjData`.

Unlike model and data wrappers, a viewer should be explicitly disposed so its
window and GUI thread are closed deterministically.
