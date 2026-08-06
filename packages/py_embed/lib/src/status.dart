import 'package:ffi/ffi.dart' as ffi;

import 'python.g.dart' as g;
import 'dylib_loader.dart';


extension PyStatusExt on g.PyStatus {
  bool get isException => api.PyStatus_Exception(this) != 0;
  String get message => err_msg.cast<ffi.Utf8>().toDartString();
  void guard() {
    if (isException) {
      throw this;
    }
  }
}
