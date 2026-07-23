import 'package:python/python.dart';

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
