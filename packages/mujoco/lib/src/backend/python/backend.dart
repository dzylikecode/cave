import 'package:py_embed/py_embed.dart';

import '../../data.dart';
import '../../model.dart';
import '../backend.dart';
import 'array.dart';
import 'sensor.dart';

final class MujocoPython implements Mujoco {
  final _module = PyModule('mujoco');

  late final _modelClass = _module.get('MjModel');
  late final _modelFromXmlString = _modelClass.get('from_xml_string');
  late final _modelFromXmlPath = _modelClass.get('from_xml_path');
  late final _dataClass = _module.get('MjData');
  late final _forward = _module.get('mj_forward');
  late final _step = _module.get('mj_step');
  late final _resetData = _module.get('mj_resetData');

  @override
  late final version = _module.getString('__version__');

  @override
  MjModel createModelFromXmlString(String xml) {
    final source = PyString(xml);
    try {
      return MjModelPython(_modelFromXmlString.call1(source));
    } finally {
      source.dispose();
    }
  }

  @override
  MjModel createModelFromXmlPath(String filePath) {
    final source = PyString(filePath);
    try {
      return MjModelPython(_modelFromXmlPath.call1(source));
    } finally {
      source.dispose();
    }
  }

  @override
  MjData createData(MjModel model) {
    final pythonModel = _requireModel(model);
    return MjDataPython(pythonModel, _dataClass.call1(pythonModel.object));
  }

  @override
  void forward(MjModel model, MjData data) {
    _callModelData(_forward, model, data);
  }

  @override
  void step(MjModel model, MjData data) {
    _callModelData(_step, model, data);
  }

  @override
  void resetData(MjModel model, MjData data) {
    _callModelData(_resetData, model, data);
  }

  /// 高频调用的时候释放，避免大量的 Python 对象占用内存
  void _callModelData(PyObject callable, MjModel model, MjData data) {
    final pythonModel = _requireModel(model);
    final pythonData = _requireData(data);
    if (!identical(pythonData.model, pythonModel)) {
      throw ArgumentError('MjData was created from a different MjModel.');
    }

    final result = callable.call2(pythonModel.object, pythonData.object);
    result.dispose();
  }

  MjModelPython _requireModel(MjModel model) {
    if (model is! MjModelPython) {
      throw ArgumentError.value(model, 'model', 'Backend mismatch');
    }
    return model;
  }

  MjDataPython _requireData(MjData data) {
    if (data is! MjDataPython) {
      throw ArgumentError.value(data, 'data', 'Backend mismatch');
    }
    return data;
  }
}

final class MjModelPython implements MjModel {
  final PyObject object;

  MjModelPython(this.object);

  @override
  late final int nq = object.getInt('nq');

  @override
  late final int nv = object.getInt('nv');

  @override
  late final int nu = object.getInt('nu');

  @override
  void dispose() => object.dispose();
}

final class MjDataPython implements MjData {
  @override
  final MjModelPython model;
  final PyObject object;

  MjDoubleArrayPython? _qpos;
  MjDoubleArrayPython? _qvel;
  MjDoubleArrayPython? _qacc;
  MjDoubleArrayPython? _ctrl;
  final Map<String, MjSensorPython> _sensors = {};

  MjDataPython(this.model, this.object);

  @override
  double get time => object.getDouble('time');

  @override
  MjDoubleArrayPython get qpos =>
      _qpos ??= MjDoubleArrayPython(object.get('qpos'), model.nq);

  @override
  MjDoubleArrayPython get qvel =>
      _qvel ??= MjDoubleArrayPython(object.get('qvel'), model.nv);

  @override
  MjDoubleArrayPython get qacc =>
      _qacc ??= MjDoubleArrayPython(object.get('qacc'), model.nv);

  @override
  MjDoubleArrayPython get ctrl =>
      _ctrl ??= MjDoubleArrayPython(object.get('ctrl'), model.nu);

  @override
  MjSensorPython sensor(String name) =>
      _sensors[name] ??= .fromData(object, name);

  @override
  void dispose() {
    _qpos?.dispose();
    _qvel?.dispose();
    _qacc?.dispose();
    _ctrl?.dispose();
    for (final sensor in _sensors.values) {
      sensor.dispose();
    }
    _sensors.clear();
    object.dispose();
  }
}
