import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:python/src/python.g.dart';

void main() async {
  final venvPython =
      Platform.environment['PYTHON_VENV_EXE'] ??
      await getPythonExecutable();

  final config = calloc<PyConfig>();
  final venvPythonPtr = venvPython.toNativeWChar();
  final script =
      '''
print("Hello from Python!")
'''
          .toNativeUtf8()
          .cast<ffi.Char>();

  try {
    PyConfig_InitPythonConfig(config);

    config.ref.program_name = venvPythonPtr;
    config.ref.executable = venvPythonPtr;

    final status = Py_InitializeFromConfig(config);
    if (PyStatus_Exception(status) != 0) {
      Py_ExitStatusException(status);
    }

    PyRun_SimpleString(script);
    Py_Finalize();
  } finally {
    calloc.free(script);
    calloc.free(venvPythonPtr);
    calloc.free(config);
  }
}

extension on String {
  ffi.Pointer<ffi.WChar> toNativeWChar() {
    final units = codeUnits;
    final result = calloc<ffi.WChar>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      result[i] = units[i];
    }
    result[units.length] = 0;
    return result;
  }
}

Future<String> runPython(
  String pythonExe,
  String code,
) async {
  final result = await Process.run(
    pythonExe,
    ['-c', code],
  );

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


Future<String> getPythonPrefix() {
  return runPython(
    'python',
    'import sys; print(sys.prefix)',
  );
}

Future<String> getPythonExecutable() {
  return runPython(
    'python',
    'import sys; print(sys.executable)',
  );
}