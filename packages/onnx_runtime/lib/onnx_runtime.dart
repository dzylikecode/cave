/// Portable ONNX Runtime interfaces with optional native C API support.
library;

export 'src/types.dart';
export 'src/backend.dart';
export 'src/session.dart';
export 'src/native.dart' if (dart.library.js_interop) 'src/native_stub.dart';
