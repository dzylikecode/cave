import 'package:py_embed/py_embed.dart';

void main() async {
  final py = Python.venv(await getPyExecutableFromShell());
  final module = PyModule('py_pkg');
  final PyFunction cls = module.get('PyClass');
  final args = PyTuple.fromList([PyString('hello')]);
  final instance = cls(args);
  final PyFunction byeFunc = instance.get('bye');
  final PyString result = byeFunc(.fromList([PyString('world')]));
  print(result.toDartString());
  py.dispose();
}