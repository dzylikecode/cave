import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final xmakeBuilder = await XmakeBuilder.create(
      project: input.packageRoot.toFilePath(),
      packageName: 'python',
      codeConfig: input.config.code,
    );

    await xmakeBuilder.config();
    await xmakeBuilder.build(target: 'minimal');
    final installedPath = await xmakeBuilder.install(
      target: 'minimal',
      libName: 'python38',
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/python.g.dart',
        file: .file(installedPath),
        linkMode: DynamicLoadingBundled(),
      ),
    );

    output.dependencies.add(input.packageRoot.resolve('xmake.lua'));
  });
}
