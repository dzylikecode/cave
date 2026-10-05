import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await XmakeLibrary(
        target: 'minimal',
        libHintName: 'mujoco',
        assetName: 'src/backend/native.g.dart',
        linkModeOption: .dynamic,
      ).build(input: input, output: output);
    }
  });
}
