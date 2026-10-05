// ignore_for_file: non_constant_identifier_names

import 'backend/python.dart';
import 'backend/native.dart';

import 'package:meta/meta.dart';

final nativeApi = const NativeApi();
final pythonApi = PythonApi();

BaseApi _api = pythonApi;
@internal
BaseApi get api => _api;

final class Mujoco {
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

abstract interface class MjData {
  factory(MjModel model) => api.MjData_new(model);

  MjModel get model;

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

  void dispose();
}

abstract interface class MjModel {
  factory from_xml_string(String xml) => api.MjModel_from_xml_string(xml);
  factory from_xml_path(String path) => api.MjModel_from_xml_path(path);

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
  int get dim;
  int get adr;
}

/// Current readings of one sensor, backed by the data's sensor buffer.
abstract interface class MjDataSensorViews {
  int get id;
  String get name;
  MjDoubleListView get data;
}
