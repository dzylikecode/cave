import 'dart:io';

Future<void> main() async {
  final result = await Process.run(
    'python',
    ['-c', 'import sys; print(sys.prefix)'],
  );

  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    return;
  }

  final prefix = (result.stdout as String).trim();
  print(prefix);
}