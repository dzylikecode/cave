import 'dart:io';
import 'package:ffigen/ffigen.dart';
import 'package:py_embed/src/venv.dart';

void main() => generateAll();

const versions = ['3.8.20'];

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

// TODO: Py_ssize_t 需要处理一下 ???
final typedefs = Typedefs.includeSet({'PyObject', 'Py_ssize_t'});

void generateBindings(String version, Uri packageRoot) {
  final v = extractVersion(version);

  final outputFile = File.fromUri(
    packageRoot.resolve('lib/src/binding/python_${v.$1}_${v.$2}_${v.$3}.g.dart'),
  );

  FfiGenerator(
    output: .new(dartFile: outputFile.uri, style: DynamicLibraryBindings()),
    headers: .new(
      entryPoints: [packageRoot.resolve('dist/$version/include/Python.h')],
      // include: (header) => header.path.endsWith('Python.h'), // 只导出这个文件的接口
      compilerOptions: [
        '-I',
        packageRoot.resolve('dist/$version/include').toFilePath(),
        if (Platform.isMacOS) ...['-isysroot', _macosSdkPath()],
        if (Platform.isWindows) ...['-include', 'winsock2.h'],
        if (Platform.isLinux) ...['-include', 'sys/time.h'],
      ],
    ),
    // macros: .includeAll,
    structs: structs,
    functions: functions,
    typedefs: typedefs,
  ).generate();
}

String _macosSdkPath() {
  final result = Process.runSync('xcrun', ['--show-sdk-path']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'xcrun',
      ['--show-sdk-path'],
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }

  final sdkPath = '${result.stdout}'.trim();
  if (sdkPath.isEmpty) {
    throw StateError('xcrun returned an empty macOS SDK path');
  }

  return sdkPath;
}

void generateAll() {
  for (final version in versions) {
    generateBindings(version, Platform.script.resolve('../'));
  }
}
