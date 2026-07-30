import 'package:py_embed/py_embed.dart';

R withPyObject<T extends PyObject, R>(T object, R Function(T object) action) {
  try {
    return action(object);
  } finally {
    object.dispose();
  }
}

PyObject call1(PyObject callable, PyObject argument) {
  final arguments = PyTuple.fromList([argument]);
  try {
    return callable.call(arguments);
  } finally {
    arguments.dispose();
  }
}

PyObject call2(PyObject callable, PyObject first, PyObject second) {
  final arguments = PyTuple.fromList([first, second]);
  try {
    return callable.call(arguments);
  } finally {
    arguments.dispose();
  }
}

int readIntAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    final value = attribute.cast<PyInt>();
    try {
      return value.value;
    } finally {
      value.dispose();
    }
  } finally {
    attribute.dispose();
  }
}

double readDoubleAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    final value = attribute.cast<PyDouble>();
    try {
      return value.value;
    } finally {
      value.dispose();
    }
  } finally {
    attribute.dispose();
  }
}

String readStringAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    final value = attribute.cast<PyString>();
    try {
      return value.value;
    } finally {
      value.dispose();
    }
  } finally {
    attribute.dispose();
  }
}
