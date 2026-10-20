# mujoco

Dart API for [MuJoCo](https://github.com/google-deepmind/mujoco).

## Resource scopes

`MjModel` and `MjData` implement `ScopedResource` for both backends:

```dart
import 'package:mujoco/mujoco.dart';

void main() => ResourceScope.scope(() {
  final model = MjModel.from_xml_path('robot.xml');
  final data = MjData(model);
  mj_step(model, data);
}); // Releases both owners and the data's array references.
```

`dispose()` is idempotent. Array and sensor views borrow their owner's resources;
do not access them after their owner is disposed.

Use `ResourceScope.returning(() => MjData(model))` to move data and its owned
array references to the caller's scope, or `detachFromScope()` for manual
ownership. Data does not own or promote its model: keep the model alive while
using data. Outside a scope, explicitly dispose data and then model.

## Backend-independent model inspection

Factories and physics functions delegate to the selected `api` abstraction.
The default implementation is Python. To use native, set `Mujoco.useNativeApi = true`
before creating models and keep that selection while those resources are in use.

```dart
final model = MjModel.from_xml_path('robot.xml');
final data = MjData(model);
try {
  print(model.timestep);
  final actuator = model.actuatorById(0);
  print(actuator.joint?.qposAddress);
  print(actuator.controlRange);
  final base = data.body('base_link');
  print(base.position.toList());
  base.appliedForce.setAll(0, [0, 0, 10, 0, 0, 0]);
  mj_step(model, data);
} finally {
  data.dispose(); model.dispose();
}
```

`MjActuatorInfo`, `MjJointInfo` and `MjBodyInfo` are metadata snapshots; they
contain no pointers or Python objects. Body position and applied-force views
are live and reject access after their owner is disposed. The wrench contains
world-frame force xyz followed by torque xyz at the body's centre of mass.
`isUnitTorqueMotor` identifies a unit-gear, unit-gain joint force actuator;
applications can additionally check the joint type.

Sensor `type` retains the backend's raw enum number. For portable logic use
`sensor.kind` (`MjSensorKind`), since enum numbering can differ between versions.
The native and Python libraries can also differ in physics behavior; do not
assume cross-version trajectories are identical.

Python integrations can import `package:mujoco/python.dart` to pass the original
Python wrappers to other Python libraries. Application logic should use the
public model/data interfaces in `package:mujoco/mujoco.dart`.
