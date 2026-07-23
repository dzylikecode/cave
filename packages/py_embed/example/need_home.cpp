#include <Python.h>

int main() {
  Py_Initialize();
  PyRun_SimpleString("print('Hello, Python!')");
  Py_Finalize();
  return 0;
}

