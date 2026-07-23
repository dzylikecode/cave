#include <Python.h>

int main() {
  Py_Initialize();
  // 需要这个，不然只有 python3.dll 没有 python38.dll
  PyRun_SimpleString("print('Hello, Python!')"); 
  Py_Finalize();
  return 0;
}

