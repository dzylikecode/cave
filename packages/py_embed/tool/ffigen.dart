import 'dart:io';
import 'package:ffigen/ffigen.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');
  final outputFile = File.fromUri(packageRoot.resolve('lib/src/python.g.dart'));
  FfiGenerator(
    output: .new(dartFile: outputFile.uri),
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
    structs: .includeSet({
      'PyConfig',
      'PyStatus',
      'PyObject',
      'PyTypeObject',
      'PyMethodDef',
    }),
    functions: .includeSet({
      'Py_Initialize',
      'Py_Finalize',
      'PyConfig_InitPythonConfig',
      'PyConfig_SetString',
      'PyStatus_Exception',
      'PyConfig_Clear',
      'Py_ExitStatusException',
      'Py_InitializeFromConfig',
      'PyRun_SimpleString',
      'PyUnicode_FromString',
      'PyImport_Import',
      'PyObject_GetAttrString',
      'PyObject_CallObject',
      'PyObject_CallMethod',
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
    }),
    typedefs: .includeSet({'PyObject'}),
  ).generate();
}
