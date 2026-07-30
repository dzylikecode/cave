import 'package:py_embed/py_embed.dart';
import 'package:meta/meta.dart';

import 'mujoco_base.dart';

class MjModel {
  @internal
  final PyObject m;

  const MjModel._(this.m);

  factory MjModel.fromXmlString(String content) {
    final cls = pyLib.get('MjModel');
    final clsFromString = cls.get('from_xml_string');
    final model = clsFromString.call(.fromList([PyString(content)]));
    return ._(model);
  }

  int get nq => m.get('nq').cast<PyInt>().value;
  int get nv => m.get('nv').cast<PyInt>().value;
  int get nu => m.get('nu').cast<PyInt>().value;
}