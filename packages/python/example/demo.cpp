#include <Python.h>

int main() {
  Py_Initialize();
  PyObject *module_name = PyUnicode_FromString("py_pkg");
  PyObject *module = PyImport_Import(module_name);

  Py_DECREF(module_name);
  PyObject *cls = PyObject_GetAttrString(module, "PyClass");

  PyObject *args = PyTuple_Pack(1, PyUnicode_FromString("dog"));

  PyObject *instance = PyObject_CallObject(cls, args);

  Py_DECREF(args);

  PyObject *result = PyObject_CallMethod(instance, "has", "s", "hello");


  Py_Finalize();
  return 0;
}
