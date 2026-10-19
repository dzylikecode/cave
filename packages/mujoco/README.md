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
