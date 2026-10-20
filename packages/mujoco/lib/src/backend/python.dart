// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';

import '../base.dart';
import '../model_info.dart';
import '../scoped_owner.dart';

final class PythonApi() implements BaseApi {
  final _mujoco = ResourceScope.unmanaged(() => PyModule('mujoco'));

  @override
  late final version = _mujoco.getAttrString('__version__');

  late final _MjModel = ResourceScope.unmanaged(
    () => _mujoco.getAttr('MjModel'),
  );
  late final _MjModel_from_xml_string = ResourceScope.unmanaged(
    () => _MjModel.getAttr('from_xml_string'),
  );
  @override
  MjModelPython MjModel_from_xml_string(String xml) {
    final model = ResourceScope.unmanaged(
      () => _MjModel_from_xml_string.forward([xml]),
    );
    return MjModelPython(model);
  }

  late final _MjModel_from_xml_path = ResourceScope.unmanaged(
    () => _MjModel.getAttr('from_xml_path'),
  );
  @override
  MjModelPython MjModel_from_xml_path(String path) {
    final model = ResourceScope.unmanaged(
      () => _MjModel_from_xml_path.forward([path]),
    );
    return MjModelPython(model);
  }

  late final _MjData = ResourceScope.unmanaged(() => _mujoco.getAttr('MjData'));
  @override
  MjDataPython MjData_new(covariant MjModelPython model) => MjDataPython(
    ResourceScope.unmanaged(() => _MjData.forward([model])),
    model,
  );

  late final _mj_forward = ResourceScope.unmanaged(
    () => _mujoco.getAttr('mj_forward'),
  );
  @override
  void mj_forward(covariant MjModelPython model, covariant MjDataPython data) {
    _mj_forward.forward([model, data]).dispose();
  }

  // 为了避免高频，而设计为如此
  late final _mj_step = ResourceScope.unmanaged(
    () => _mujoco.getAttr('mj_step'),
  );
  @override
  void mj_step(covariant MjModelPython model, covariant MjDataPython data) {
    _mj_step.forward([model, data]).dispose();
  }

  late final _mj_resetData = ResourceScope.unmanaged(
    () => _mujoco.getAttr('mj_resetData'),
  );
  @override
  void mj_resetData(
    covariant MjModelPython model,
    covariant MjDataPython data,
  ) {
    _mj_resetData.forward([model, data]).dispose();
  }
}

class MjModelPython(@override final PyObject handle)
    with ScopedOwner
    implements MjModel, PyObjectWrapper {
  this {
    handle.detachFromScope();
    ResourceScope.track(this);
  }

  @override
  double get timestep => ResourceScope.scope(
    () => handle.getAttr('opt').getAttrDouble('timestep'),
  );
  @override
  int get njnt => handle.getAttrInt('njnt');
  @override
  int get nbody => handle.getAttrInt('nbody');

  PyObject _at(String field, int row, [int? column]) {
    final key = column == null
        ? PyInt(row)
        : PyTuple.fromList([PyInt(row), PyInt(column)]);
    return handle.getAttr(field).getItem(key);
  }

  int _intAt(String field, int row, [int? column]) =>
      _at(field, row, column).asInt();
  double _doubleAt(String field, int row, [int? column]) =>
      _at(field, row, column).asDouble();
  String _name(String kind, int id) =>
      handle.getAttr(kind).forward([id]).getAttrString('name');
  @override
  MjJointInfo jointById(int id) => ResourceScope.scope(() {
    if (isDisposed) throw StateError('Model is disposed');
    RangeError.checkValidIndex(id, this, 'id', njnt);
    return .new(
      id: id,
      name: _name('joint', id),
      type: MjJointType.values[_intAt('jnt_type', id)],
      qposAddress: _intAt('jnt_qposadr', id),
      dofAddress: _intAt('jnt_dofadr', id),
    );
  });
  @override
  MjActuatorInfo actuatorById(int id) => ResourceScope.scope(() {
    if (isDisposed) throw StateError('Model is disposed');
    RangeError.checkValidIndex(id, this, 'id', nu);
    final jointTransmission = _intAt('actuator_trntype', id) == 0;
    final joint = jointTransmission
        ? jointById(_intAt('actuator_trnid', id, 0))
        : null;
    final unitGear =
        _doubleAt('actuator_gear', id, 0) == 1 &&
        List.generate(
          5,
          (i) => _doubleAt('actuator_gear', id, i + 1),
        ).every((v) => v == 0);
    return .new(
      id: id,
      name: _name('actuator', id),
      joint: joint,
      isUnitTorqueMotor:
          jointTransmission &&
          unitGear &&
          _intAt('actuator_dyntype', id) == 0 &&
          _intAt('actuator_gaintype', id) == 0 &&
          _intAt('actuator_biastype', id) == 0 &&
          _doubleAt('actuator_gainprm', id, 0) == 1,
      controlRange: _at('actuator_ctrllimited', id).asBool()
          ? (
              lower: _doubleAt('actuator_ctrlrange', id, 0),
              upper: _doubleAt('actuator_ctrlrange', id, 1),
            )
          : null,
    );
  });
  @override
  MjBodyInfo body(String name) => ResourceScope.scope(() {
    if (isDisposed) throw StateError('Model is disposed');
    try {
      final view = handle.getAttr('body').forward([name]);
      return bodyById(view.getAttrInt('id'));
    } on PyException {
      throw ArgumentError.value(name, 'name', 'Unknown body');
    }
  });
  @override
  MjBodyInfo bodyById(int id) => ResourceScope.scope(() {
    if (isDisposed) throw StateError('Model is disposed');
    RangeError.checkValidIndex(id, this, 'id', nbody);
    return .new(id, _name('body', id));
  });

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
  MjModelSensorViewsPython sensor(String name) => ResourceScope.scope(() {
    final method = handle.getAttr('sensor');
    final view = method.forward([name]);
    return sensorById(view.getAttrInt('id'));
  });

  @override
  MjModelSensorViewsPython sensorById(int id) {
    RangeError.checkValidIndex(id, this, 'id', nsensor);
    return MjModelSensorViewsPython(this, id);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    handle.dispose();
  }
}

class MjDataPython(
  @override final PyObject handle,
  @override final MjModelPython model,
) with ScopedOwner implements MjData, PyObjectWrapper {
  this {
    handle.detachFromScope();
    ResourceScope.track(this);
  }

  MjDoubleListViewPython _flatArray(String name) => MjDoubleListViewPython(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(
        () => handle.getAttr(name).getAttr('reshape').forward([-1]),
      ),
    ),
  );
  late final MjDoubleListViewPython _bodyPositions = _flatArray('xpos');
  late final MjDoubleListViewPython _bodyForces = _flatArray('xfrc_applied');
  // Track initialization without evaluating a lazy array during disposal.
  bool _bodyArraysCreated = false;
  void _ensureBodyArrays() {
    if (!_bodyArraysCreated) {
      _bodyPositions;
      _bodyForces;
      _bodyArraysCreated = true;
    }
  }

  @override
  MjDataBodyViews body(String name) => bodyById(model.body(name).id);
  @override
  MjDataBodyViews bodyById(int id) {
    if (isDisposed || model.isDisposed) {
      throw StateError('Model or data is disposed');
    }
    final info = model.bodyById(id);
    _ensureBodyArrays();
    return MjDataBodyViewsPython(this, info);
  }

  @override
  double get time => handle.getAttrDouble('time');

  @override
  final MjDoubleListViewPython qpos = .new(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('qpos')),
    ),
  );

  @override
  final MjDoubleListViewPython qvel = .new(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('qvel')),
    ),
  );

  @override
  final MjDoubleListViewPython qacc = .new(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('qacc')),
    ),
  );

  @override
  final MjDoubleListViewPython act = .new(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('act')),
    ),
  );

  @override
  final MjDoubleListViewPython ctrl = .new(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('ctrl')),
    ),
  );

  @override
  final MjDoubleListViewPython sensordata = .new(
    ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('sensordata')),
    ),
  );

  @override
  MjDataSensorViewsPython sensor(String name) =>
      sensorById(model.sensor(name).id);

  @override
  MjDataSensorViewsPython sensorById(int id) =>
      MjDataSensorViewsPython(this, model.sensorById(id));

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    qpos.handle.dispose();
    qvel.handle.dispose();
    qacc.handle.dispose();
    act.handle.dispose();
    ctrl.handle.dispose();
    sensordata.handle.dispose();
    if (_bodyArraysCreated) {
      _bodyPositions.handle.dispose();
      _bodyForces.handle.dispose();
    }
    handle.dispose();
  }
}

class const MjDoubleListViewPython(@override final PyObject handle)
    implements MjDoubleListView, PyObjectWrapper {
  @override
  int get length => handle.getAttrInt('size');

  @override
  double operator [](int index) => ResourceScope.scope(() {
    final item = handle.getItem(PyInt(index));
    return item.asDouble();
  });

  @override
  void operator []=(int index, double value) => ResourceScope.scope(() {
    handle.setItem(PyInt(index), PyDouble(value));
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
  T _withView<T>(T Function(PyObject) action) => ResourceScope.scope(() {
    final method = model.handle.getAttr('sensor');
    final view = method.forward([id]);
    return action(view);
  });

  int _getInt(String field) => ResourceScope.scope(() {
    final array = model.handle.getAttr('sensor_$field');
    return array.getItem(PyInt(id)).asInt();
  });

  @override
  String get name => _withView((view) => view.getAttrString('name'));

  @override
  int get type => _getInt('type');

  @override
  MjSensorKind get kind => ResourceScope.scope(() {
    final types = PyModule('mujoco').getAttr('mjtSensor');
    for (final entry in {
      'mjSENS_ACCELEROMETER': MjSensorKind.accelerometer,
      'mjSENS_GYRO': MjSensorKind.gyro,
      'mjSENS_FRAMEQUAT': MjSensorKind.frameQuaternion,
    }.entries) {
      if (type == types.getAttr(entry.key).asInt()) return entry.value;
    }
    return .other;
  });

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

class MjDataBodyViewsPython(final MjDataPython owner, final MjBodyInfo info)
    implements MjDataBodyViews {
  @override
  int get id => info.id;
  @override
  String get name => info.name;
  @override
  late final MjDoubleListView position = _MjBodySlicePython(
    owner,
    owner._bodyPositions,
    3 * id,
    3,
  );
  @override
  late final MjDoubleListView appliedForce = _MjBodySlicePython(
    owner,
    owner._bodyForces,
    6 * id,
    6,
  );
}

class _MjBodySlicePython(
  final MjDataPython owner,
  final MjDoubleListViewPython source,
  final int offset,
  final int size,
) implements MjDoubleListView {
  void _check() {
    if (owner.isDisposed || owner.model.isDisposed) {
      throw StateError('Model or data is disposed');
    }
  }

  @override
  int get length {
    _check();
    return size;
  }

  @override
  double operator [](int index) {
    _check();
    RangeError.checkValidIndex(index, this, 'index', size);
    return source[offset + index];
  }

  @override
  void operator []=(int index, double value) {
    _check();
    RangeError.checkValidIndex(index, this, 'index', size);
    source[offset + index] = value;
  }

  @override
  List<double> toList() => List.generate(length, (i) => this[i]);
}
