# Local bgfx recipe

Based on xmake-repo `packages/b/bgfx/xmake.lua` at commit
`a32d7e4ed13b8bbb8563c5cc4ee415fa333fd040` (Apache-2.0).

Local changes:

- Skip `--with-tools`: the Dart runtime does not need shaderc or texturec.
- Add `dart_static_sections` to compile position independent code with separate function/data sections.
- Add `export_c_api` to preserve C symbol visibility for static AOT linking.
- Add `merge_static` to merge bgfx, bimg and bx into the installed bgfx archive.

These options are part of the xmake package cache key. The project installs
one library with a stable bgfx name, regardless of upstream Release/Debug naming.
The native versions and vendored headers must be updated together. After updating,
regenerate ffigen output and repeat Noop, tests and AOT packaging checks.

The recipe retains upstream platform limitations. Only Linux x64 has been exercised
in this workspace; platform linker dependencies are specified in `hook/link.dart`.
