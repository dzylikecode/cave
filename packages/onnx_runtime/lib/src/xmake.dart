import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

final xmakeLibrary = XmakeLibrary(
  target: 'onnxruntime_dart',
  libHintName: 'onnxruntime',
  assetName: 'src/third_party/ort.g.dart',
);
