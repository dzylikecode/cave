import 'package:py_embed/src/python.g.dart' as g;
import 'package:py_embed/py_embed.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;

void main() async {
  final py = Python.venv(await getPyExecutableFromShell());

  final module_name = g.PyUnicode_FromString("py_pkg".toNativeUtf8().cast<Char>());

  py.dispose();
}