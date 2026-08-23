import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:console_bars/console_bars.dart';

const versions = ['3.8.10'];

Future<void> main() async {
  final rootDir = Directory.fromUri(Platform.script.resolve('../'));
  final cacheDir = Directory(p.join(rootDir.path, '.cache', 'cpython'));
  final workDir = Directory(p.join(rootDir.path, '.dart_tool', 'cpython'));
  final distDir = Directory(p.join(rootDir.path, 'dist'));

  await cacheDir.create(recursive: true);
  await workDir.create(recursive: true);
  await distDir.create(recursive: true);

  for (final version in versions) {
    await _fetchHeaders(
      version: version,
      rootDir: rootDir,
      cacheDir: cacheDir,
      workDir: workDir,
      distDir: distDir,
    );
  }
}

Future<void> _fetchHeaders({
  required String version,
  required Directory rootDir,
  required Directory cacheDir,
  required Directory workDir,
  required Directory distDir,
}) async {
  final archiveName = 'Python-$version.tar.xz';
  final archiveFile = File(p.join(cacheDir.path, archiveName));
  final url = Uri.parse(
    'https://www.python.org/ftp/python/$version/$archiveName',
  );

  if (!await archiveFile.exists()) {
    stdout.writeln('fetch $url to $archiveFile');
    late FillingBar bar;
    await _download(
      url,
      archiveFile,
      onTotal: (total) {
        bar = FillingBar(
          desc: 'Downloading',
          total: total,
          percentage: true,
          time: true,
          width: stdout.hasTerminal ? null : 60,
        );
      },
      onProgress: (downloaded) {
        bar.update(downloaded);
      },
    );
  } else {
    stdout.writeln('Using cached $archiveFile');
  }

  final extractDir = Directory(p.join(workDir.path, version));
  if (!await extractDir.exists()) {
    await extractDir.create(recursive: true);

    stdout.writeln('Extracting $archiveFile');
    await _runTar(archiveFile, extractDir);
  }

  final sourceRoot = Directory(p.join(extractDir.path, 'Python-$version'));
  final sourceInclude = Directory(p.join(sourceRoot.path, 'Include'));
  if (!await sourceInclude.exists()) {
    throw StateError('Missing Include directory in ${sourceRoot.path}');
  }

  final targetInclude = Directory(p.join(distDir.path, version, 'include'));
  if (await targetInclude.exists()) {
    await targetInclude.delete(recursive: true);
  }
  await targetInclude.create(recursive: true);

  await _copyDirectory(sourceInclude, targetInclude);

  final windowsPyConfig = File(p.join(sourceRoot.path, 'PC', 'pyconfig.h'));
  if (await windowsPyConfig.exists()) {
    await windowsPyConfig.copy(p.join(targetInclude.path, 'pyconfig.h'));
  }

  stdout.writeln('Wrote $targetInclude');
}

Future<void> _download(
  Uri url,
  File output, {
  void Function(int total)? onTotal,
  void Function(int downloaded)? onProgress,
}) async {
  final client = HttpClient();

  try {
    final request = await client.getUrl(url);
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $url: HTTP ${response.statusCode}',
        uri: url,
      );
    }

    final total = response.contentLength;
    onTotal?.call(total);

    var downloaded = 0;

    final tempFile = File('${output.path}.download');
    final sink = tempFile.openWrite();

    try {
      await response
          .map((chunk) {
            downloaded += chunk.length;
            onProgress?.call(downloaded);
            return chunk;
          })
          .pipe(sink);
    } finally {
      await sink.close();
    }

    if (await output.exists()) {
      await output.delete();
    }

    await tempFile.rename(output.path);
  } finally {
    client.close(force: true);
  }
}

Future<void> _runTar(File archiveFile, Directory extractDir) async {
  // windows 有 tar
  final result = await Process.run('tar', [
    '-xf',
    archiveFile.path,
    '-C',
    extractDir.path,
  ]);

  if (result.exitCode != 0) {
    throw ProcessException(
      'tar',
      ['-xf', archiveFile.path, '-C', extractDir.path],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await for (final entity in source.list(recursive: true)) {
    final relativePath = _relative(source, entity);
    final targetPath = p.join(target.path, relativePath);

    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(File(targetPath).parent.path).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

String _relative(Directory from, FileSystemEntity entity) {
  return p.relative(entity.path, from: from.path);
}
