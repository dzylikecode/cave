import 'package:py_embed/py_embed.dart';
import 'package:meta/meta.dart';

import 'model.dart';
import 'data.dart';

@internal
final pyLib = PyModule('mujoco');


class Mujoco {
  static final version = pyLib.get('__version__').cast<PyString>().value;
}


void mjForward(MjModel model, MjData data) {
  final func = pyLib.get('mj_forward');
  func.call(.fromList([model.m, data.m]));
}