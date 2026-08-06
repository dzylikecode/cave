import 'dart:io';

const _printPythonLibrary =
    'import os, sys, sysconfig; '
    'name = sysconfig.get_config_var("LDLIBRARY"); '
    'directory = sys.base_prefix if sys.platform == "win32" '
    'else sysconfig.get_config_var("LIBDIR"); '
    'assert name and directory, "Python does not provide a shared library"; '
    'print(os.path.join(directory, name))';

Future<String> runPyShell(String code, [String pyExe = 'python']) async {
  final result = await Process.run(pyExe, ['-c', code]);

  if (result.exitCode != 0) {
    throw ProcessException(
      pyExe,
      ['-c', code],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  return result.stdout.toString().trim();
}

String runPyShellSync(String code, [String pyExe = 'python']) {
  final result = Process.runSync(pyExe, ['-c', code]);

  if (result.exitCode != 0) {
    throw ProcessException(
      pyExe,
      ['-c', code],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  return result.stdout.toString().trim();
}

Future<String> getPyPrefixFromShell([String pyExe = 'python']) =>
    runPyShell('import sys; print(sys.prefix)', pyExe);
Future<String> getPyExecutableFromShell([String pyExe = 'python']) =>
    runPyShell('import sys; print(sys.executable)', pyExe);
Future<String> getPyBasePrefixFromShell([String pyExe = 'python']) =>
    runPyShell('import sys; print(sys.base_prefix)', pyExe);
Future<String> getPyLibraryFromShell([String pyExe = 'python']) =>
    runPyShell(_printPythonLibrary, pyExe);

String getPyPrefixFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.prefix)', pyExe);
String getPyExecutableFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.executable)', pyExe);
String getPyBasePrefixFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.base_prefix)', pyExe);
String getPyLibraryFromShellSync([String pyExe = 'python']) =>
    runPyShellSync(_printPythonLibrary, pyExe);
