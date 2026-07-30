import 'package:py_embed/py_embed.dart';

import '../backend.dart';
import 'python_array.dart';
import 'python_helpers.dart';

final class PythonMujocoBackend implements MujocoBackend {
  final PyModule _module = PyModule('mujoco');

  late final PyObject _modelClass = _module.get('MjModel');
  late final PyObject _modelFromXmlString = _modelClass.get('from_xml_string');
  late final PyObject _modelFromXmlFile = _modelClass.get('from_xml_file');
  late final PyObject _dataClass = _module.get('MjData');
  late final PyObject _forward = _module.get('mj_forward');
  late final PyObject _step = _module.get('mj_step');
  late final PyObject _resetData = _module.get('mj_resetData');

  @override
  late final String version = readStringAttribute(_module, '__version__');

  @override
  BackendModel createModelFromXmlString(String xml) {
    final source = PyString(xml);
    try {
      return PythonBackendModel(call1(_modelFromXmlString, source));
    } finally {
      source.dispose();
    }
  }

  @override
  BackendModel createModelFromXmlFile(String filePath) {
    final source = PyString(filePath);
    try {
      return PythonBackendModel(call1(_modelFromXmlFile, source));
    } finally {
      source.dispose();
    }
  }

  @override
  BackendData createData(BackendModel model) {
    final pythonModel = _requireModel(model);
    return PythonBackendData(
      pythonModel,
      call1(_dataClass, pythonModel.object),
    );
  }

  @override
  void forward(BackendModel model, BackendData data) {
    _callModelData(_forward, model, data);
  }

  @override
  void step(BackendModel model, BackendData data) {
    _callModelData(_step, model, data);
  }

  @override
  void resetData(BackendModel model, BackendData data) {
    _callModelData(_resetData, model, data);
  }

  /// 高频调用的时候释放，避免大量的 Python 对象占用内存
  void _callModelData(PyObject callable, BackendModel model, BackendData data) {
    final pythonModel = _requireModel(model);
    final pythonData = _requireData(data);
    if (!identical(pythonData.model, pythonModel)) {
      throw ArgumentError('MjData was created from a different MjModel.');
    }

    final result = call2(callable, pythonModel.object, pythonData.object);
    result.dispose();
  }

  PythonBackendModel _requireModel(BackendModel model) {
    if (model is! PythonBackendModel) {
      throw ArgumentError.value(model, 'model', 'Backend mismatch');
    }
    return model;
  }

  PythonBackendData _requireData(BackendData data) {
    if (data is! PythonBackendData) {
      throw ArgumentError.value(data, 'data', 'Backend mismatch');
    }
    return data;
  }
}

final class PythonBackendModel implements BackendModel {
  final PyObject object;

  PythonBackendModel(this.object);

  @override
  late final int nq = readIntAttribute(object, 'nq');

  @override
  late final int nv = readIntAttribute(object, 'nv');

  @override
  late final int nu = readIntAttribute(object, 'nu');

  @override
  void dispose() => object.dispose();
}

final class PythonBackendData implements BackendData {
  final PythonBackendModel model;
  final PyObject object;

  PythonMjDoubleArray? _qpos;
  PythonMjDoubleArray? _qvel;
  PythonMjDoubleArray? _qacc;
  PythonMjDoubleArray? _ctrl;

  PythonBackendData(this.model, this.object);

  @override
  double get time => readDoubleAttribute(object, 'time');

  @override
  PythonMjDoubleArray get qpos =>
      _qpos ??= PythonMjDoubleArray(object.get('qpos'), model.nq);

  @override
  PythonMjDoubleArray get qvel =>
      _qvel ??= PythonMjDoubleArray(object.get('qvel'), model.nv);

  @override
  PythonMjDoubleArray get qacc =>
      _qacc ??= PythonMjDoubleArray(object.get('qacc'), model.nv);

  @override
  PythonMjDoubleArray get ctrl =>
      _ctrl ??= PythonMjDoubleArray(object.get('ctrl'), model.nu);

  @override
  void dispose() {
    _qpos?.dispose();
    _qvel?.dispose();
    _qacc?.dispose();
    _ctrl?.dispose();
    object.dispose();
  }
}
