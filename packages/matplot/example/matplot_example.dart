import 'package:py_embed/py_embed.dart';

void main() async {
  final py = Python.venv(await getPyExecutableFromShell());
  final np = PyModule('numpy');
  final PyFunction arrage = np.get('arange');
  // final t = arrage.call(.fromList([0.0, 2.0, 0.01].map()))
  py.dispose();
}
