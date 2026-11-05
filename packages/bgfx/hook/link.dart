// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:bgfx/src/third_party/bgfx.record_use_mapping.g.dart';
import 'package:bgfx/src/xmake.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: .treeshake(
        // The merged archive contains C++ implementations behind the C API.
        flags: switch (input.config.code.targetOS) {
          OS.linux => ['-lstdc++', '-lm', '-ldl', '-lpthread', '-lX11', '-lGL'],
          OS.macOS => [
            '-lc++',
            '-framework',
            'Metal',
            '-framework',
            'QuartzCore',
            '-framework',
            'Cocoa',
            '-framework',
            'IOKit',
            '-framework',
            'VideoToolbox',
            '-framework',
            'CoreMedia',
            '-framework',
            'CoreVideo',
          ],
          OS.iOS => [
            '-lc++',
            '-framework',
            'Metal',
            '-framework',
            'QuartzCore',
            '-framework',
            'UIKit',
            '-framework',
            'OpenGLES',
            '-framework',
            'CoreGraphics',
            '-framework',
            'VideoToolbox',
            '-framework',
            'CoreMedia',
            '-framework',
            'CoreVideo',
          ],
          OS.windows => ['user32.lib', 'gdi32.lib', 'psapi.lib'],
          _ => [],
        },
        symbolsToKeep: input.recordedUses?.calls.keys
            .where(
              (definition) =>
                  definition.library.uri ==
                  'package:bgfx/src/third_party/bgfx.g.dart',
            )
            .map((definition) => recordUseMapping[definition.name]!),
      ),
    );
  });
}
