import 'dart:io';
import 'package:ffigen/ffigen.dart';

final structs = Structs.includeSet({
  'PyConfig',
  'PyStatus',
  'PyObject',
  'PyTypeObject',
  'PyMethodDef',
});

final functions = Functions.includeSet({
  'Py_Initialize',
  'Py_Finalize',
  'PyConfig_InitPythonConfig',
  'PyConfig_SetString',
  'PyStatus_Exception',
  'PyConfig_Clear',
  'Py_ExitStatusException',
  'Py_InitializeFromConfig',
  'PyRun_SimpleString',
  // errors
  'PyErr_Occurred',
  'PyErr_Clear',
  'PyErr_Fetch',
  'PyErr_NormalizeException',
  'PyExceptionClass_Name',
  'PyImport_Import',

  /// ## object
  /// [object](https://github.com/python/cpython/blob/main/Include/object.h)
  'PyObject_GetAttrString',
  'PyObject_SetAttrString',
  'PyObject_HasAttrString',
  'PyObject_Str',

  /// [operator[]=](https://github.com/python/cpython/blob/main/Include/abstract.h)
  'PyObject_GetItem',
  'PyObject_SetItem',
  'PyObject_DelItemString',
  'PyObject_DelItem',
  'Py_DecRef',
  'Py_IncRef',
  // tuple
  'PyTuple_New',
  'PyTuple_Size',
  'PyTuple_GetItem',
  'PyTuple_SetItem',
  'PyTuple_GetSlice',
  // list
  'PyList_New',
  'PyList_Size',
  'PyList_GetItem',
  'PyList_SetItem',
  'PyList_Insert',
  'PyList_Append',
  'PyList_GetSlice',
  'PyList_SetSlice',
  'PyList_Sort',
  'PyList_Reverse',
  'PyList_AsTuple',
  // dict
  'PyDict_New',
  'PyDict_GetItem',
  'PyDict_GetItemWithError',
  'PyDict_SetItem',
  'PyDict_DelItem',
  'PyDict_Clear',
  'PyDict_Next',
  'PyDict_Keys',
  'PyDict_Values',
  'PyDict_Items',
  'PyDict_Size',
  'PyDict_Copy',
  'PyDict_Contains',
  'PyDict_Update',
  'PyDict_Merge',
  'PyDict_MergeFromSeq2',
  'PyDict_GetItemString',
  'PyDict_SetItemString',
  'PyDict_DelItemString',
  // function
  'PyObject_Call',
  'PyObject_CallObject',
  // string
  'PyUnicode_FromString',
  'PyUnicode_AsUTF8String',
  'PyBytes_AsString',
  // bool
  'PyBool_FromLong',
  'PyObject_IsTrue',
  'PyObject_Not',
  // int
  'PyLong_FromLong',
  'PyLong_AsLong',
  // double
  'PyFloat_FromDouble',
  'PyFloat_AsDouble',
  // operators
  'PyNumber_Add',
  'PyNumber_Subtract',
  'PyNumber_Multiply',
  'PyNumber_TrueDivide',
  'PyNumber_FloorDivide',
  'PyNumber_Remainder',
  'PyNumber_Power',
  'PyNumber_Negative',
});

final typedefs = Typedefs.includeSet({
  'Py_ssize_t',
  'Py_hash_t',
});

void main() {
  final packageRoot = Platform.script.resolve('../');
  final outputFile = File.fromUri(packageRoot.resolve('lib/src/python.g.dart'));

  FfiGenerator(
    output: .new(dartFile: outputFile.uri, style: DynamicLibraryBindings()),
    headers: .new(
      entryPoints: [packageRoot.resolve('dist/include/Python.h')],
      // include: (header) => header.path.endsWith('Python.h'), // 只导出这个文件的接口
      compilerOptions: [
        '-I',
        packageRoot.resolve('dist/include').toFilePath(),
        if (Platform.isWindows) ...['-include', 'winsock2.h'],
        if (Platform.isLinux || Platform.isMacOS) ...['-include', 'sys/time.h'],
      ],
    ),
    // macros: .includeAll,
    structs: structs,
    functions: functions,
    // TODO: Py_ssize_t 需要处理一下
    typedefs: typedefs,
  ).generate();
}
