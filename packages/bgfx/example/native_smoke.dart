// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:ffi';

import 'package:bgfx/bgfx.dart';
import 'package:ffi/ffi.dart';

void main() {
  // Run rendering on this thread, without a platform window or GPU.
  bgfx_render_frame(-1);
  final init = calloc<bgfx_init_t>();
  try {
    bgfx_init_ctor(init);
    init.ref.type = .BGFX_RENDERER_TYPE_NOOP;
    init.ref.resolution.width = 64;
    init.ref.resolution.height = 64;
    if (!bgfx_init(init)) throw StateError('bgfx initialization failed');
    try {
      if (bgfx_get_renderer_type() != .BGFX_RENDERER_TYPE_NOOP) {
        throw StateError('Expected Noop renderer');
      }
      bgfx_set_view_rect(0, 0, 0, 64, 64);
      bgfx_set_view_clear(
        0,
        BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH,
        0x303030ff,
        1,
        0,
      );
      bgfx_touch(0);
      final first = bgfx_frame(0);
      bgfx_touch(0);
      final second = bgfx_frame(0);
      if (second != first + 1) {
        throw StateError('Frame counter did not advance');
      }
      print('bgfx Noop: frames $first -> $second');
    } finally {
      bgfx_shutdown();
    }
  } finally {
    calloc.free(init);
  }
}
