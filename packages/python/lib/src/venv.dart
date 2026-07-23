import 'dart:io';

Future<String> runPyShell(String code, [String pythonExe = 'python']) async {
  final result = await Process.run(pythonExe, ['-c', code]);

  if (result.exitCode != 0) {
    throw ProcessException(
      pythonExe,
      ['-c', code],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  return result.stdout.toString().trim();
}

Future<String> getPythonPrefix() => runPyShell('import sys; print(sys.prefix)');
Future<String> getPythonExecutable() => runPyShell('import sys; print(sys.executable)');
