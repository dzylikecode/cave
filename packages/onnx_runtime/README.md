# onnx_runtime

Dart FFI wrapper for ONNX Runtime 1.22.0 (C API 22). No Python or C++ bridge
is required. Native libraries are managed by xmake and Dart build hooks.

Supports CPU synchronous inference, named float32 inputs and outputs, multiple
inputs/outputs, dynamic dimensions, and explicit resource disposal. Output data
is copied into Dart memory and remains valid after another run or disposal.
Other tensor element types, GPU providers, and zero-copy reusable inference
buffers are not implemented yet. Each run currently allocates native buffers;
this API is not yet optimized for a real-time control loop.

## Native asset pruning

The hooks share `XmakeLibrary`'s default `.byPreference` configuration and use
the dedicated `onnxruntime_dart` export target. The local recipe under
`xmake_repo/packages/o/onnxruntime/` retains official precompiled binaries for
development and builds the pinned CPU runtime from source for AOT linking.
Source builds require Python 3, CMake 3.28, and Ninja; the recipe supplies
CMake and Ninja. The
initial source build downloads upstream dependencies and takes substantially
longer than development builds. Installed packages are reused afterward.

The recipe obtains the exact static link inputs from CMake's File API and merges
them into one archive. The Dart link hook records `OrtGetApiBase` usage and either
includes the native code asset or omits it entirely when unused. The C API's
function-pointer table still retains its referenced implementations; this does
not provide per-operator pruning. Missing usage recordings conservatively retain
the library. See [local recipe details](xmake_repo/README.md).

```sh
dart run example/native_smoke.dart
dart run tool/verify_native_assets.dart
```

The smoke example embeds the tiny Add model from `test/fixtures/add.onnx`, so its
compiled executable runs independently of the source tree. The verification
script checks inference and a second bundle that uses only `OrtTensor`. Both
checks pass on Linux x64: the used bundle exports only `OrtGetApiBase`, has no
dependency on the upstream runtime DSO, and the unused bundle contains no ONNX
Runtime library.

## Native library

Install xmake and make it available on `PATH`. On the first `dart run`,
`dart test`, or native build, `hook/build.dart` uses `native_toolchain_xmake`
to resolve the pinned CPU package, install its selected library, and register
it as a code asset. Development uses a shared library; AOT routes the merged
static archive through the link hook. Later runs reuse the build cache.
Xmake verifies downloads using the package recipe checksums. The repository
revision is recorded in `xmake-requires.lock`.

No library path, environment variable, or system-wide ONNX Runtime install is
needed. Package acquisition requires network access on the first build.
Only Linux x64 has been validated in this workspace. Other platforms need
separate validation of their shared binaries and static source toolchains.

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

## Portable backend API

The public tensor, backend and asynchronous session interfaces do not import
`dart:ffi` or `dart:io`. The native implementation is conditionally exported;
a JavaScript backend can implement `OrtBackend` and `OrtSessionHandler` using
`onnxruntime-web`. That adapter is not implemented yet.

```dart
final session = await OrtInferenceSession.create(
  modelBytes,
  backend: OrtNativeBackend(),
  options: const OrtSessionOptions(intraOpNumThreads: 1),
);
try {
  final outputs = await session.run(feeds);
  print(outputs);
} finally {
  await session.dispose();
}
```

`OrtNativeBackend()` owns and releases a runtime per session. Pass
`OrtNativeBackend(runtime: runtime)` to share an externally owned runtime;
dispose all sessions before releasing that runtime. Await active runs before
session disposal. The asynchronous native adapter still executes inference on
the calling isolate. Use the existing `OrtSession.run()` for synchronous native
inference; `OrtSession.fromBytes()` also accepts model bytes directly.

This first separation retains float32 tensors and all-output inference. Typed
values, model metadata, selected/preallocated outputs and provider options are
future additions to the common API.
