import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';
import 'package:path/path.dart' as p;
import 'package:py_embed/src/venv.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // final xmakeBuilder = await XmakeBuilder.create(
    //   project: input.packageRoot.toFilePath(),
    //   packageName: 'python',
    //   codeConfig: input.config.code,
    // );

    // await xmakeBuilder.config();
    // await xmakeBuilder.build(target: 'minimal');
    // final installedPath = await xmakeBuilder.install(
    //   target: 'minimal',
    //   libName: switch (input.config.code.targetOS) {
    //     .windows => 'python38',
    //     _ => 'python3.8',
    //   },
    // );

    final basePrefix = await getPyBasePrefixFromShell();

    final libName = input.config.code.targetOS.libraryFileName(
      switch (input.config.code.targetOS) {
        .windows => 'python38',
        _ => 'python3.8',
      },
      LookupInProcess(),
    );

    final installedPath = p.join(basePrefix, 'lib', libName);

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/python.g.dart',
        file: .file(installedPath),
        linkMode: LookupInProcess(),
      ),
    );

    output.dependencies.add(input.packageRoot.resolve('xmake.lua'));
  });
}
