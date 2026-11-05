// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:io';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  final checks = Directory.fromUri(
    packageRoot.resolve('.dart_tool/native_assets_check/'),
  )..createSync(recursive: true);
  final runDirectory = checks.createTempSync('run_');

  Future<void> run(String executable, List<String> arguments) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: packageRoot.toFilePath(),
      environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        'Native asset verification failed',
        result.exitCode,
      );
    }
  }

  Future<Uri> build(String entryPoint, String name) async {
    final output = runDirectory.uri.resolve('$name/');
    await run(Platform.resolvedExecutable, [
      'build',
      'cli',
      '--target=$entryPoint',
      '--output=${output.toFilePath()}',
    ]);
    return output.resolve('bundle/');
  }

  List<File> bgfxLibraries(Uri bundle) {
    final libraries = Directory.fromUri(bundle.resolve('lib/'));
    if (!libraries.existsSync()) return [];
    return libraries.listSync().whereType<File>().where((file) {
      return file.uri.pathSegments.last.contains('bgfx');
    }).toList();
  }

  Future<void> runBundle(Uri bundle) async {
    final executable = Directory.fromUri(bundle.resolve('bin/'))
        .listSync()
        .whereType<File>()
        .single;
    await run(executable.path, []);
  }

  final used = await build('example/native_smoke.dart', 'used');
  if (bgfxLibraries(used).length != 1) {
    throw StateError('Expected one bundled bgfx library: $used');
  }
  await runBundle(used);
  if (Platform.isLinux) {
    final library = bgfxLibraries(used).single;
    final result = await Process.run('nm', [
      '-D',
      '--defined-only',
      library.path,
    ]);
    if (result.exitCode != 0) throw StateError('nm failed: ${result.stderr}');
    final symbols = (result.stdout as String)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim().split(RegExp(r'\s+')).last)
        .toSet();
    if (!symbols.contains('bgfx_init') ||
        symbols.contains('bgfx_create_shader')) {
      throw StateError('Unexpected native exports: $symbols');
    }
  }

  final unusedSource = File.fromUri(runDirectory.uri.resolve('unused.dart'));
  unusedSource.writeAsStringSync('''
// ignore: unused_import
import 'package:bgfx/bgfx.dart';
void main() { print('bgfx imported without native calls'); }
''');
  final unused = await build(unusedSource.path, 'unused');
  if (bgfxLibraries(unused).isNotEmpty) {
    throw StateError('Unused bgfx library was bundled: $unused');
  }
  await runBundle(unused);
  print('Native asset checks passed. Artifacts: ${runDirectory.path}');
}
