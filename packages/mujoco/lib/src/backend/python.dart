// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';

import '../base.dart';

final class PythonApi() implements BaseApi {
  final _mujoco = PyModule('mujoco');

  @override
  late final version = _mujoco.getAttrString('__version__');

  late final _MjModel = _mujoco.getAttr('MjModel');
  late final _MjModel_from_xml_string = _MjModel.getAttr('from_xml_string');
  @override
  MjModelPython MjModel_from_xml_string(String xml) {
    final model = _MjModel_from_xml_string.forward([xml]);
    return MjModelPython(model);
  }

  late final _MjModel_from_xml_path = _MjModel.getAttr('from_xml_path');
  @override
  MjModelPython MjModel_from_xml_path(String path) {
    final model = _MjModel_from_xml_path.forward([path]);
    return MjModelPython(model);
  }

  late final _MjData = _mujoco.getAttr('MjData');
  @override
  MjDataPython MjData_new(covariant MjModelPython model) =>
      MjDataPython(_MjData.forward([model]), model);

  late final _mj_forward = _mujoco.getAttr('mj_forward');
  @override
  void mj_forward(covariant MjModelPython model, covariant MjDataPython data) {
    _mj_forward.forward([model, data]).ref.discrement();
  }

  late final _mj_step = _mujoco.getAttr('mj_step');
  @override
  void mj_step(covariant MjModelPython model, covariant MjDataPython data) {
    _mj_step.forward([model, data]).ref.discrement();
  }

  late final _mj_resetData = _mujoco.getAttr('mj_resetData');
  @override
  void mj_resetData(
    covariant MjModelPython model,
    covariant MjDataPython data,
  ) {
    _mj_resetData.forward([model, data]).ref.discrement();
  }
}

class const MjModelPython(@override final PyObject handle)
    implements MjModel, PyObjectWrapper {
  @override
  int get nq => handle.getAttrInt('nq');

  @override
  int get nv => handle.getAttrInt('nv');

  @override
  int get nu => handle.getAttrInt('nu');

  @override
  int get na => handle.getAttrInt('na');

  @override
  int get nsensor => handle.getAttrInt('nsensor');

  @override
  int get nsensordata => handle.getAttrInt('nsensordata');

  @override
  MjModelSensorViewsPython sensor(String name) => Py.using((scope) {
    final method = scope(handle.getAttr('sensor'));
    final view = scope(method.forward([name]));
    return sensorById(view.getAttrInt('id'));
  });

  @override
  MjModelSensorViewsPython sensorById(int id) {
    RangeError.checkValidIndex(id, this, 'id', nsensor);
    return MjModelSensorViewsPython(this, id);
  }

  @override
  void dispose() => handle.ref.discrement();
}

class MjDataPython(
  @override final PyObject handle,
  @override final MjModelPython model,
) implements MjData, PyObjectWrapper {
  @override
  double get time => handle.getAttrDouble('time');

  @override
  final MjDoubleListViewPython qpos = .new(handle.getAttr('qpos'));

  @override
  final MjDoubleListViewPython qvel = .new(handle.getAttr('qvel'));

  @override
  final MjDoubleListViewPython qacc = .new(handle.getAttr('qacc'));

  @override
  final MjDoubleListViewPython act = .new(handle.getAttr('act'));

  @override
  final MjDoubleListViewPython ctrl = .new(handle.getAttr('ctrl'));

  @override
  final MjDoubleListViewPython sensordata = .new(handle.getAttr('sensordata'));

  @override
  MjDataSensorViewsPython sensor(String name) =>
      sensorById(model.sensor(name).id);

  @override
  MjDataSensorViewsPython sensorById(int id) =>
      MjDataSensorViewsPython(this, model.sensorById(id));

  @override
  void dispose() {
    qpos.handle.ref.discrement();
    qvel.handle.ref.discrement();
    qacc.handle.ref.discrement();
    act.handle.ref.discrement();
    ctrl.handle.ref.discrement();
    sensordata.handle.ref.discrement();
    handle.ref.discrement();
  }
}

class const MjDoubleListViewPython(@override final PyObject handle)
    implements MjDoubleListView, PyObjectWrapper {
  @override
  int get length => handle.getAttrInt('size');

  @override
  double operator [](int index) => Py.using((scope) {
    final item = scope(handle.getItem(scope(PyInt(index))));
    return item.asDouble();
  });

  @override
  void operator []=(int index, double value) => Py.using((scope) {
    handle.setItem(scope(PyInt(index)), scope(PyDouble(value)));
  });

  @override
  List<double> toList() {
    final list = <double>[];
    for (var i = 0; i < length; i++) {
      list.add(this[i]);
    }
    return list;
  }
}

class MjModelSensorViewsPython(
  final MjModelPython model,
  @override final int id,
) implements MjModelSensorViews {
  T _withView<T>(T Function(PyObject) action) => Py.using((scope) {
    final method = scope(model.handle.getAttr('sensor'));
    final view = scope(method.forward([id]));
    return action(view);
  });

  int _getInt(String field) => Py.using((scope) {
    final array = scope(model.handle.getAttr('sensor_$field'));
    return scope(array.getItem(scope(PyInt(id)))).asInt();
  });

  @override
  String get name => _withView((view) => view.getAttrString('name'));

  @override
  int get type => _getInt('type');

  @override
  int get dim => _getInt('dim');

  @override
  int get adr => _getInt('adr');
}

class MjDataSensorViewsPython(
  final MjDataPython owner,
  final MjModelSensorViewsPython sensor,
) implements MjDataSensorViews {
  @override
  int get id => sensor.id;

  @override
  String get name => sensor.name;

  @override
  final MjDoubleListView data = _MjSensorDataSlicePython(
    owner.sensordata,
    sensor.adr,
    sensor.dim,
  );
}

class _MjSensorDataSlicePython(
  final MjDoubleListViewPython source,
  final int offset,
  @override final int length,
) implements MjDoubleListView {
  @override
  double operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return source[offset + index];
  }

  @override
  void operator []=(int index, double value) {
    RangeError.checkValidIndex(index, this, 'index', length);
    source[offset + index] = value;
  }

  @override
  List<double> toList() => .generate(length, (index) => this[index]);
}
