# mujoco

Dart API for [MuJoCo](https://github.com/google-deepmind/mujoco).

## Native asset pruning

The build and link hooks share the `XmakeLibrary` in `lib/src/xmake.dart`, using
its default `.byPreference` mode and the dedicated `mujoco_dart` xmake target.
The `minimal` executable remains an independent C++ example.

A local recipe in `xmake_repo/packages/m/mujoco/xmake.lua`, following the
`cserialport` repository layout, owns the MuJoCo-specific build adjustments.
For AOT builds, its `export_c_api` configuration preserves C API visibility,
and `merge_static` merges the required dependencies into the package's installed
static archive. These configurations are part of the package cache key. The
project target only exports the finished library to
`dist/<os>/<architecture>/lib/libmujoco.a` (`mujoco.lib` on Windows).

The local recipe selects reentrant Qhull (`qhullstatic_r`) and excludes the extra
TinyObjLoader archive because MuJoCo already embeds it in `obj_decoder.cc`.
See [the local repository notes](xmake_repo/README.md) for the upstream recipe
revision, configuration constraints, and update instructions.
The link hook supplies the C++ runtime libraries and retains the FFI symbols
recorded by the Dart compiler. No recorded native calls means no MuJoCo library
in the final bundle; missing usage recordings conservatively retain all symbols.

Development builds install the original shared MuJoCo library directly from
the xmake package, rather than building a wrapper shared library. The build hook
tracks `xmake.lua`, `xmake-requires.lock`, and the local recipe so configuration
changes invalidate its cache.

Run the native smoke example and the AOT packaging checks from this package:

```sh
dart run example/native_smoke.dart
dart run tool/verify_native_assets.dart
```

The smoke example compiles a tetrahedral mesh and advances the simulation. The
verification script builds and runs both a used-native bundle and an unused
import bundle, checking whether the native library is included. It saves its
artifacts under `.dart_tool/native_assets_check/` for inspection.

The complete flow has been tested on Linux x64. Windows, macOS, Android, and iOS
branches have not been verified on their target platforms.

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
