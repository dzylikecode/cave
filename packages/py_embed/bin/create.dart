// TODO 感觉不是很需要

import 'dart:io';

const pyVersion = '3.8.10';

Future<int> main(List<String> args) async {
  print('hello world');
  return 0;
}


/// use uv to create a python virtual environment and install the specified python version
Future<void> create(String pyVersion) async {
  final result = await Process.run('uv', ['install', pyVersion]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'uv',
      ['install', pyVersion],
      result.stderr.toString(),
      result.exitCode,
    );
  }
}
