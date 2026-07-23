import 'package:py_embed/py_embed.dart';

void main() async {
  final python = Python();
  python.initFromConfig(
    PyConfig()
      ..executable = await getPythonExecutable()
      ..programName = await getPythonExecutable(),
  );

  python.runSimpleString('print("Hello from Python!")');

  python.dispose();
}
