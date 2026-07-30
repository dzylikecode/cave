import 'package:py_embed/py_embed.dart';
import 'package:meta/meta.dart';

import 'model.dart';
import 'data.dart';

@internal
final pyLib = PyModule('mujoco');

abstract final class Mujoco {
  static final version = pyLib.get('__version__').cast<PyString>().value;
}

void mjForward(MjModel model, MjData data) =>
    pyLib.get('mj_forward')(.fromList([model.m, data.m]));
