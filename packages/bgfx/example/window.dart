// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:bgfx/bgfx.dart';
import 'package:ffi/ffi.dart';

import 'lib/src/third_party/x11.g.dart' as x;

/// A shader-free animated bgfx scene in a native Linux/X11 window.
/// Run with --frames=120 for a bounded rendering check.
void main(List<String> args) {
  if (!Platform.isLinux) {
    throw UnsupportedError('This example requires Linux and an X11 display.');
  }
  final frameLimit = args.isEmpty
      ? null
      : int.tryParse(args.single.replaceFirst('--frames=', ''));
  if (args.isNotEmpty && (frameLimit == null || frameLimit <= 0)) {
    throw ArgumentError('Usage: dart run example/window.dart [--frames=N]');
  }
  // Xext installs callbacks on Display. Keep it loaded until XCloseDisplay,
  // even when bgfx unloads its GPU driver during shutdown.
  DynamicLibrary.open('libXext.so.6');
  final x11 = x.X11(DynamicLibrary.open('libX11.so.6'));
  final display = x11.XOpenDisplay(nullptr);
  if (display == nullptr) {
    throw StateError('Cannot open X11 display. Check DISPLAY and Xauthority.');
  }

  var window = 0;
  var initialized = false;
  final event = calloc<x.XEvent>();
  final attributes = calloc<x.XWindowAttributes>();
  final closeAtom = calloc<UnsignedLong>();
  final init = calloc<bgfx_init_t>();
  final text = calloc<Uint8>(100 * 2);
  try {
    var width = 960;
    var height = 640;
    window = x11.XCreateSimpleWindow(
      display,
      x11.XDefaultRootWindow(display),
      80,
      80,
      width,
      height,
      0,
      0,
      0,
    );
    if (window == 0) throw StateError('Cannot create X11 window.');
    using((arena) {
      x11.XStoreName(
        display,
        window,
        'Dart + bgfx | Color Wave'.toNativeUtf8(allocator: arena).cast(),
      );
      closeAtom.value = x11.XInternAtom(
        display,
        'WM_DELETE_WINDOW'.toNativeUtf8(allocator: arena).cast(),
        0,
      );
      x11.XSetWMProtocols(display, window, closeAtom, 1);
    });
    x11.XSelectInput(display, window, x.KeyPressMask | x.StructureNotifyMask);
    x11.XMapWindow(display, window);
    x11.XFlush(display);

    // No async gaps: X11 events, bgfx API and rendering stay on this thread.
    bgfx_render_frame(-1);
    bgfx_init_ctor(init);
    init.ref.type = .BGFX_RENDERER_TYPE_COUNT;
    init.ref.platformData.ndt = display.cast();
    init.ref.platformData.nwh = Pointer<Void>.fromAddress(window);
    init.ref.platformData.type = .BGFX_NATIVE_WINDOW_HANDLE_TYPE_DEFAULT;
    init.ref.resolution.width = width;
    init.ref.resolution.height = height;
    init.ref.resolution.reset = BGFX_RESET_VSYNC;
    if (!bgfx_init(init)) throw StateError('Cannot initialize bgfx renderer.');
    initialized = true;
    bgfx_set_debug(BGFX_DEBUG_TEXT);
    final renderer = bgfx_get_renderer_name(bgfx_get_renderer_type())
        .cast<Utf8>()
        .toDartString();
    print('Rendering with $renderer. Resize the window; press Esc to exit.');

    final clock = Stopwatch()..start();
    var frames = 0;
    var running = true;
    while (running && (frameLimit == null || frames < frameLimit)) {
      while (x11.XPending(display) > 0) {
        x11.XNextEvent(display, event);
        switch (event.ref.type) {
          case x.KeyPress:
            if (x11.XLookupKeysym(event.cast<x.XKeyEvent>(), 0) == 0xff1b) {
              running = false; // XK_Escape
            }
          case x.ClientMessage:
            if (event.ref.xclient.data.l[0] == closeAtom.value) running = false;
          case x.DestroyNotify:
            window = 0;
            running = false;
        }
      }
      if (!running) break;
      if (x11.XGetWindowAttributes(display, window, attributes) == 0) break;
      final nextWidth = attributes.ref.width.clamp(1, 65535);
      final nextHeight = attributes.ref.height.clamp(1, 65535);
      if (nextWidth != width || nextHeight != height) {
        width = nextWidth;
        height = nextHeight;
        bgfx_reset(width, height, BGFX_RESET_VSYNC, .BGFX_TEXTURE_FORMAT_COUNT);
      }

      final t = clock.elapsedMicroseconds / 1000000;
      _scene(width, height, t);
      bgfx_dbg_text_clear(0, false);
      _label(text, 2, 1, 'DART + BGFX / COLOR WAVE', 0x0f);
      _label(text, 2, 3, '$renderer | frame $frames', 0x0b);
      if (height >= 80) {
        _label(text, 2, height ~/ 16 - 2, 'ESC exit   /   resize window', 0x07);
      }
      bgfx_frame(0);
      frames++;
      sleep(const Duration(milliseconds: 8));
    }
    print('Rendered $frames frames.');
  } finally {
    if (initialized) bgfx_shutdown();
    if (window != 0) x11.XDestroyWindow(display, window);
    x11.XCloseDisplay(display);
    calloc.free(text);
    calloc.free(init);
    calloc.free(closeAtom);
    calloc.free(attributes);
    calloc.free(event);
  }
}

// Each view clears a rectangle. This exercises actual GPU rendering without
// requiring precompiled shaders, vertex buffers or an external shaderc tool.
void _scene(int width, int height, double t) {
  var view = 0;
  void rectangle(double x, double y, double w, double h, int color) {
    final left = x.round().clamp(0, width - 1);
    final top = y.round().clamp(0, height - 1);
    final right = (x + w).round().clamp(left + 1, width);
    final bottom = (y + h).round().clamp(top + 1, height);
    bgfx_set_view_rect(view, left, top, right - left, bottom - top);
    bgfx_set_view_clear(view, BGFX_CLEAR_COLOR, color, 1, 0);
    bgfx_touch(view++);
  }

  rectangle(0, 0, width.toDouble(), height.toDouble(), 0x101828ff);
  const columns = 24;
  const rows = 12;
  // Keep below bgfx's default 256-view limit.
  const gridColumns = 20;
  final cell = math.min(width / columns, height / (rows + 6));
  final originX = (width - gridColumns * cell) / 2;
  final originY = (height - rows * cell) / 2;
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < gridColumns; col++) {
      final wave = math.sin(col * 0.35 + row * 0.5 - t * 2);
      final pulse = (wave + 1) / 2;
      final red = (40 + 170 * pulse).round();
      final green = (100 + 100 * math.sin(t + col * 0.2).abs()).round();
      final blue = (200 + 50 * (1 - pulse)).round();
      final inset = cell * (0.08 + 0.16 * (1 - pulse));
      rectangle(
        originX + col * cell + inset,
        originY + row * cell + inset,
        cell - 2 * inset,
        cell - 2 * inset,
        (red << 24) | (green << 16) | (blue << 8) | 0xff,
      );
    }
  }
  final progress = (math.sin(t) + 1) / 2;
  rectangle(
    originX,
    originY + (rows + 1) * cell,
    gridColumns * cell,
    4,
    0x253550ff,
  );
  rectangle(
    originX,
    originY + (rows + 1) * cell,
    math.max(1, gridColumns * cell * progress),
    4,
    0x63e6beff,
  );
}

void _label(Pointer<Uint8> buffer, int x, int y, String value, int attribute) {
  final count = math.min(value.length, 100);
  for (var i = 0; i < count; i++) {
    buffer[i * 2] = value.codeUnitAt(i);
    buffer[i * 2 + 1] = attribute;
  }
  bgfx_dbg_text_image(x, y, count, 1, buffer.cast(), count * 2);
}
