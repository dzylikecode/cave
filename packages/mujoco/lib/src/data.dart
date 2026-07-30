import 'package:py_embed/py_embed.dart';
import 'package:meta/meta.dart';

import 'model.dart';
import 'mujoco_base.dart';

class MjData {
  @internal
  final PyObject m;
  const MjData._(this.m);

  factory MjData(MjModel model) {
    final cls = pyLib.get('MjData');
    final data = cls.call(.fromList([model.m]));
    return ._(data);
  }

  double get time => m.get('time').cast<PyDouble>().value;
  List<double> get qpos {
    final array = m.get('qpos');
    final list = array.get('tolist').call(PyTuple()).cast<PyList>();

    return .generate(
      list.length,
      (index) => list.getItem(index).cast<PyDouble>().value,
    );
  }

  List<double> get qvel {
    final array = m.get('qvel');
    final list = array.get('tolist').call(PyTuple()).cast<PyList>();

    return .generate(
      list.length,
      (index) => list.getItem(index).cast<PyDouble>().value,
    );
  }
}
