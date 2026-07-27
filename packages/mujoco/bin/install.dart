import 'dart:io';

Future<int> main(List<String> args) async {
  return install();
}


Future<int> install() async {
  final result = await Process.run('pip', ['install', 'mujoco']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'pip',
      ['install', 'mujoco'],
      result.stderr.toString(),
      result.exitCode,
    );
  }
  return 0;
}
