import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

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

String getPyPrefixFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.prefix)', pyExe);
String getPyExecutableFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.executable)', pyExe);
String getPyBasePrefixFromShellSync([String pyExe = 'python']) =>
    runPyShellSync('import sys; print(sys.base_prefix)', pyExe);

@internal
(int, int, int) extractVersion(String versionString) {
  final version = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(versionString);
  if (version == null) {
    throw FormatException('Invalid Python version string: $versionString');
  }
  return (
    .parse(version.group(1)!),
    .parse(version.group(2)!),
    .parse(version.group(3)!),
  );
}

(int, int, int) getPyVersionSync([String pyExe = 'python']) {
  final result = Process.runSync(pyExe, ['--version']);

  if (result.exitCode != 0) {
    throw ProcessException(
      pyExe,
      ['--version'],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  final output = result.stdout.toString().trim();
  return extractVersion(output);
}

String getPyDllPathFromVenvSync([String pyExe = 'python']) {
  final basePrefix = getPyBasePrefixFromShellSync(pyExe);
  final version = getPyVersionSync(pyExe);
  final path = switch (true) {
    _ when Platform.isLinux => p.join(
      basePrefix,
      'lib',
      'libpython${version.$1}.${version.$2}.so',
    ),
    _ when Platform.isWindows => p.join(
      basePrefix,
      'python${version.$1}${version.$2}.dll',
    ),
    _ when Platform.isMacOS => p.join(
      basePrefix,
      'lib',
      'libpython${version.$1}.${version.$2}.dylib',
    ),
    _ => throw UnsupportedError('Platform not implemented.'),
  };
  if (!File(path).existsSync()) {
    throw Exception('Python shared library not found at $path');
  }
  return path;
}
