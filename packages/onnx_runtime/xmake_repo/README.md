# Local ONNX Runtime package

The recipe follows the local-repository layout used by `cserialport` and the
MuJoCo package. Its shared-binary paths come from xmake-repo commit
`a32d7e4ed13b8bbb8563c5cc4ee415fa333fd040`.

## Build modes

- `shared=true`: install the official CPU runtime binary, retaining its checksum.
- `shared=false, merge_static=true`: build CPU ONNX Runtime 1.22.0 from the
  official source archive, then merge its required static libraries. GPU static
  builds and other source versions are explicitly rejected.

The source SHA-256 is
`08b078eb7afbf376064b2b0f1781e3d78151cac0592988a0c0ec78bf72fde810`.
CMake 3.28.1, Ninja, and Python 3 are build-time requirements. The recipe supplies
CMake and Ninja. Static builds retain normal
CPU operators; this is not a reduced-operator/model-specific build. Tests,
benchmarks, Python bindings, training, and accelerator providers are not enabled.
Compiler concurrency is capped at four processes to limit memory use.

ONNX Runtime's CMake definitions select the library dependencies. A small
excluded-from-all link target exposes that resolved list through the CMake File
API; the recipe merges those exact archives instead of globbing all `.a` files
(which would mix unrelated protobuf/protoc variants). The manifest target itself
is never built or installed. An archive-only build target ensures its external
dependencies are built as well. The session target keeps default symbol
visibility so the C API can be exported when the merged archive is relinked
into a Dart code asset.

## Pinned Eigen archive correction

ONNX Runtime 1.22.0's original Eigen ZIP SHA-1 no longer matches GitLab's archive
for the same commit. See upstream issue
https://github.com/microsoft/onnxruntime/issues/24861.
The local recipe keeps Eigen commit
`1d8b82b0740839c0de7f1242a3585e3390ff5f33` and its original URL, and updates the
expected SHA-1 to `51982be81bbe52572b54180454df11a3ece9a934`. The inspected ZIP
comment identifies that exact commit; its SHA-256 is
`0a11e4f71593a1335cae38c4847bb9f36e1b700148c0d257abfca9df802115c2`.
Download verification remains enabled.

## Development

The project's `onnxruntime_dart` target only exports the completed package
library. `minimal` remains an independent C example. Static source builds use a
build-hash-specific cache directory so configurations stay separate and failed
builds can reuse downloaded dependencies.

After editing package installation logic, run `xmake f -c` with the desired kind
and `xmake require -f onnxruntime` to refresh its cached build. Dart hook dependency
tracking reruns xmake, but does not force xmake to rebuild installed packages.

Use `dart run tool/verify_native_assets.dart` from the package root to validate
native Add inference and exclusion of the native library when only Dart types
are used. Source-build validation status is reported in the project README.
