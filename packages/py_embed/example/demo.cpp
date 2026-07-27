#include <Python.h>

int main() {
  const wchar_t *venvPython =
      LR"(PATH\.venv\Scripts\python.exe)";

  PyConfig config;
  PyConfig_InitPythonConfig(&config);

  PyStatus status =
      PyConfig_SetString(&config, &config.program_name, venvPython);

  if (!PyStatus_Exception(status)) {
    status = PyConfig_SetString(&config, &config.executable, venvPython);
  }

  if (PyStatus_Exception(status)) {
    PyConfig_Clear(&config);
    Py_ExitStatusException(status);
  }

  status = Py_InitializeFromConfig(&config);
  PyConfig_Clear(&config);

  if (PyStatus_Exception(status)) {
    Py_ExitStatusException(status);
  }
  PyObject *module_name = PyUnicode_FromString("py_pkg");
  PyObject *module = PyImport_Import(module_name);

  Py_DECREF(module_name);
  PyObject *cls = PyObject_GetAttrString(module, "PyClass");

  PyObject *args = PyTuple_Pack(1, PyUnicode_FromString("dog"));

  PyObject *instance = PyObject_CallObject(cls, args);

  Py_DECREF(args);

  PyObject *result = PyObject_CallMethod(instance, "bye", "s", "hello");

  if (result) {
    if (PyUnicode_Check(result)) {
      const char *str = PyUnicode_AsUTF8(result);
      if (str) {
        printf("Result: %s\n", str);
      } else {
        printf("Result is not a valid UTF-8 string.\n");
      }
    }

    Py_DECREF(result);
  } else {
    PyErr_Print();
  }
  Py_Finalize();
  return 0;
}
