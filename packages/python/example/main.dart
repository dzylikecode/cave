import 'package:py_embed/py_embed.dart';

void main() async {
  final py = Python.venv(await getPyExecutableFromShell());

  py.runSimpleString('print("Hello from Python!")');

  py.dispose();
}
