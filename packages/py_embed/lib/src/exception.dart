import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;

/// A Python exception translated at the Python/Dart API boundary.
final class PythonException implements Exception {
  final String type;
  final String message;
  final String? context;

  const PythonException({
    required this.type,
    required this.message,
    this.context,
  });

  @override
  String toString() {
    final description = message.isEmpty ? type : '$type: $message';
    return context == null
        ? 'PythonException: $description'
        : 'PythonException while $context: $description';
  }
}

@internal
void checkPythonError({String? context}) {
  if (g.PyErr_Occurred() != nullptr) {
    throwPythonException(context: context);
  }
}

@internal
Never throwPythonException({String? context}) {
  if (g.PyErr_Occurred() == nullptr) {
    throw PythonException(
      type: 'UnknownPythonError',
      message: 'A Python API reported failure without setting an exception.',
      context: context,
    );
  }

  return ffi.using((arena) {
    final type = arena<Pointer<g.PyObject>>()..value = nullptr;
    final value = arena<Pointer<g.PyObject>>()..value = nullptr;
    final traceback = arena<Pointer<g.PyObject>>()..value = nullptr;

    g.PyErr_Fetch(type, value, traceback);
    g.PyErr_NormalizeException(type, value, traceback);

    try {
      throw PythonException(
        type: _exceptionTypeName(type.value),
        message: objectToDartString(value.value, suppressErrors: true),
        context: context,
      );
    } finally {
      _xDecRef(type.value);
      _xDecRef(value.value);
      _xDecRef(traceback.value);
    }
  });
}

String _exceptionTypeName(Pointer<g.PyObject> type) {
  if (type == nullptr) return 'UnknownPythonError';

  final name = g.PyExceptionClass_Name(type);
  if (name == nullptr) {
    g.PyErr_Clear();
    return 'UnknownPythonError';
  }
  return name.cast<ffi.Utf8>().toDartString();
}

/// Converts any Python object using `PyObject_Str`.
///
/// Exception formatting uses [suppressErrors] to avoid recursively throwing
/// while an existing Python exception is being translated.
@internal
String objectToDartString(
  Pointer<g.PyObject> object, {
  bool suppressErrors = false,
}) {
  if (object == nullptr) return '';

  final string = g.PyObject_Str(object);
  if (string == nullptr) {
    if (!suppressErrors) {
      throwPythonException(context: 'converting a Python object to string');
    }
    g.PyErr_Clear();
    return '<failed to format Python object>';
  }

  try {
    final bytes = g.PyUnicode_AsUTF8String(string);
    if (bytes == nullptr) {
      if (!suppressErrors) {
        throwPythonException(context: 'encoding a Python string as UTF-8');
      }
      g.PyErr_Clear();
      return '<failed to encode Python object>';
    }

    try {
      final value = g.PyBytes_AsString(bytes);
      if (value == nullptr) {
        if (!suppressErrors) {
          throwPythonException(context: 'reading a Python string');
        }
        g.PyErr_Clear();
        return '<failed to read Python object>';
      }
      return value.cast<ffi.Utf8>().toDartString();
    } finally {
      g.Py_DecRef(bytes);
    }
  } finally {
    g.Py_DecRef(string);
  }
}

void _xDecRef(Pointer<g.PyObject> pointer) {
  if (pointer != nullptr) g.Py_DecRef(pointer);
}
