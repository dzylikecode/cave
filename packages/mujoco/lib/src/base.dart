// ignore_for_file: non_constant_identifier_names

import 'backend/python.dart';
import 'model_info.dart';
import 'backend/native.dart';

import 'package:meta/meta.dart';
import 'package:resource_scope/resource_scope.dart';

@internal
final nativeApi = const NativeApi();
@internal
final pythonApi = PythonApi();

BaseApi _api = pythonApi;
@internal
BaseApi get api => _api;

abstract final class Mujoco {
  static String get version => api.version;
  static bool _isUsingNativeApi = false;
  static set useNativeApi(bool useNative) {
    _isUsingNativeApi = useNative;
    _api = useNative ? nativeApi : pythonApi;
  }

  static bool get useNativeApi => _isUsingNativeApi;
}

void mj_forward(MjModel model, MjData data) => api.mj_forward(model, data);
void mj_step(MjModel model, MjData data) => api.mj_step(model, data);
void mj_resetData(MjModel model, MjData data) => api.mj_resetData(model, data);

@internal
abstract interface class BaseApi {
  String get version;
  MjData MjData_new(MjModel model);
  MjModel MjModel_from_xml_string(String xml);
  MjModel MjModel_from_xml_path(String path);
  void mj_forward(MjModel model, MjData data);
  void mj_step(MjModel model, MjData data);
  void mj_resetData(MjModel model, MjData data);
}

abstract interface class MjData implements ScopedResource {
  factory(MjModel model) => api.MjData_new(model);

  MjModel get model;

  /// Looks up a body's world position and applied wrench by name.
  MjDataBodyViews body(String name);

  /// Looks up body data by ID, including world body zero.
  MjDataBodyViews bodyById(int id);

  double get time;

  MjDoubleListView get qpos;
  MjDoubleListView get qvel;
  MjDoubleListView get qacc;
  MjDoubleListView get act;
  MjDoubleListView get ctrl;

  /// 存放所有的传感器数据
  ///
  /// 原本二维的数据表被展平成一维数组
  ///
  /// ```txt
  /// sensor1: [0, 1, 2, 3]
  /// sensor2: [4, 5, 6]
  /// sensor3: [7, 8]
  /// ```
  ///
  /// 然后被展平成一维数组
  ///
  /// ```txt
  /// sensordata: [0, 1, 2, 3, 4, 5, 6, 7, 8]
  /// ```
  ///
  /// 通过 [adr, adr + ndim) 来访问
  MjDoubleListView get sensordata;

  /// Looks up a sensor by name.
  /// The returned view is valid until this data or its model is disposed.
  MjDataSensorViews sensor(String name);

  /// Looks up a sensor by ID, with the same lifetime as [sensor].
  MjDataSensorViews sensorById(int id);

  @override
  void dispose();
}

abstract interface class MjModel implements ScopedResource {
  factory from_xml_string(String xml) => api.MjModel_from_xml_string(xml);
  factory from_xml_path(String path) => api.MjModel_from_xml_path(path);

  /// The physics timestep in seconds.
  double get timestep;

  /// The number of joints in the compiled model.
  int get njnt;

  /// The number of bodies, including the world body.
  int get nbody;

  /// Returns a snapshot of joint metadata by ID.
  MjJointInfo jointById(int id);

  /// Returns a snapshot of actuator metadata by ID.
  MjActuatorInfo actuatorById(int id);

  /// Returns a body's metadata by name.
  MjBodyInfo body(String name);

  /// Returns a body's metadata by ID.
  MjBodyInfo bodyById(int id);

  /// Number of generalized position coordinates in [MjData.qpos].
  int get nq;

  /// Number of degrees of freedom in [MjData.qvel] and [MjData.qacc].
  int get nv;

  /// Number of actuator control inputs in [MjData.ctrl].
  int get nu;

  /// Number of actuator activation states in [MjData.act].
  int get na;

  /// Number of sensors in the model.
  int get nsensor;

  /// Total number of scalar sensor readings in [MjData.sensordata].
  int get nsensordata;

  /// Looks up a sensor by name.
  /// The returned view is valid until this model is disposed.
  MjModelSensorViews sensor(String name);

  /// Looks up a sensor by ID, with the same lifetime as [sensor].
  MjModelSensorViews sensorById(int id);

  @override
  void dispose();
}

abstract interface class MjDoubleListView {
  int get length;
  double operator [](int index);
  void operator []=(int index, double value);
  List<double> toList();
}

/// Configuration of one sensor in a compiled model.
abstract interface class MjModelSensorViews {
  int get id;
  String get name;
  int get type;

  /// The sensor's meaning independent of backend-specific enum numbering.
  MjSensorKind get kind;
  int get dim;
  int get adr;
}

/// Current readings of one sensor, backed by the data's sensor buffer.
abstract interface class MjDataSensorViews {
  int get id;
  String get name;
  MjDoubleListView get data;
}

/// Live body data with the lifetime of its owning model and data.
abstract interface class MjDataBodyViews {
  int get id;
  String get name;

  /// The body frame's world position, in metres.
  MjDoubleListView get position;

  /// The applied world-frame wrench: force xyz followed by torque xyz.
  ///
  /// This maps to MuJoCo's `xfrc_applied` at the body's centre of mass.
  MjDoubleListView get appliedForce;
}

/// Bounded bulk operations shared by both backends.
extension MjDoubleListOperations on MjDoubleListView {
  /// Copies values beginning at [index], following Dart List semantics.
  void setAll(int index, Iterable<double> values) {
    final copy = values.toList(growable: false);
    RangeError.checkValidRange(index, index + copy.length, length);
    for (var i = 0; i < copy.length; i++) {
      this[index + i] = copy[i];
    }
  }

  /// Fills the half-open interval with [value].
  void fillRange(int start, int end, double value) {
    RangeError.checkValidRange(start, end, length);
    for (var i = start; i < end; i++) {
      this[i] = value;
    }
  }
}
