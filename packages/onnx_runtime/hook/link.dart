import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:onnx_runtime/src/third_party/ort.record_use_mapping.g.dart';
import 'package:onnx_runtime/src/xmake.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: .treeshake(
        flags: switch (input.config.code.targetOS) {
          OS.linux => ['-lstdc++', '-lm', '-ldl', '-lpthread', '-lrt'],
          OS.macOS || OS.iOS => ['-lc++'],
          _ => [],
        },
        symbolsToKeep: input.recordedUses?.calls.keys
            .where(
              (definition) =>
                  definition.library.uri ==
                  'package:onnx_runtime/src/third_party/ort.g.dart',
            )
            .map((definition) => recordUseMapping[definition.name]!),
      ),
    );
  });
}
