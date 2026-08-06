import 'package:py_embed/py_embed.dart';

void main() async {
  final module = PyModule('py_pkg');
  final cls = module.get('PyClass');
  final args = PyTuple.fromList([PyString('hello')]);
  final instance = cls(args);
  final byeFunc = instance.get('bye');
  final PyString result = byeFunc(.fromList([PyString('world')])).cast();
  print(result.value);
  Python.shutdown();
}
