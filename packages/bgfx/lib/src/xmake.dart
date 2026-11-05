// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

final xmakeLibrary = XmakeLibrary(
  target: 'bgfx_dart',
  libHintName: 'bgfx',
  assetName: 'src/third_party/bgfx.g.dart',
);
