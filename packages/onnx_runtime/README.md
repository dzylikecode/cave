# onnx_runtime

Dart FFI wrapper for ONNX Runtime 1.22.0 (C API 22). No Python or C++ bridge
is required. Native libraries are managed by xmake and Dart build hooks.

Supports CPU synchronous inference, named float32 inputs and outputs, multiple
inputs/outputs, dynamic dimensions, and explicit resource disposal. Output data
is copied into Dart memory and remains valid after another run or disposal.
Other tensor element types, GPU providers, and zero-copy reusable inference
buffers are not implemented yet. Each run currently allocates native buffers;
this API is not yet optimized for a real-time control loop.

## Native library

Install xmake and make it available on `PATH`. On the first `dart run`,
`dart test`, or native build, `hook/build.dart` uses `native_toolchain_xmake`
to resolve the pinned CPU shared package, install its runtime library, and
register it as a bundled code asset. Later runs reuse the build cache.
Xmake verifies downloads using the package recipe checksums. The repository
revision is recorded in `xmake-requires.lock`.

No library path, environment variable, or system-wide ONNX Runtime install is
needed. Package acquisition requires network access on the first build.
Only the Linux x64 build has been tested in this workspace; other targets
require an ONNX Runtime binary supported by the xmake package.

```dart
import 'dart:typed_data';
import 'package:onnx_runtime/onnx_runtime.dart';

void main() {
  final runtime = OrtRuntime();
  try {
    final session = OrtSession.fromFile(runtime, 'policy.onnx', threads: 1);
    try {
      final outputs = session.run({
        session.inputNames.single: OrtTensor([1, 760], Float32List(760)),
      });
      print(outputs[session.outputNames.single]!.data);
    } finally {
      session.dispose();
    }
  } finally {
    runtime.dispose();
  }
}
```

Dispose sessions before their runtime. Disposal is idempotent. A session cannot
be used after disposal. Native failures throw `OrtException`. Model loading
uses bytes, so filenames are handled by Dart on every platform. Only Linux x64
has been tested in this workspace.

## Development

```sh
# Export headers from the same xmake package used by the hook:
xmake f -y --mode=release
xmake build api_export
dart run tool/ffigen.dart
dart analyze
dart test
# Build a distributable bundle including the runtime library:
dart build cli --target=example/onnx_runtime_example.dart
# Workspace AMP smoke test (from this package directory):
dart run example/onnx_runtime_example.dart \
  ../../../loong_gui_sim/runtime/model/onnx/linglong2_amp_15000.onnx
```

Distribute the entire `bundle/` directory (both `bin/` and `lib/`).
Use `dart build cli` for native assets; `dart compile exe` alone does not
produce the native-asset bundle.

Native inference tests run by default through the build hook.
`test/fixtures/add.onnx` is a small
ONNX IR 8 / opset 13 graph computing `sum = a + b`, with float32 inputs of shape
`[batch, 2]`. It verifies numerical results and dynamic batch handling.

Headers are exported to the ignored `dist/include/` directory. The MIT license
is preserved in `third_party/onnxruntime/LICENSE`. Bindings in
`lib/src/third_party/` are generated; do not edit them manually. The `minimal`
xmake target is a small native version probe, matching the MuJoCo package design;
its shared package dependency is what the Dart hook bundles.
