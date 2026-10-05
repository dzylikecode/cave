
// ignore_for_file: non_constant_identifier_names
import 'package:meta/meta.dart';

import 'package:mujoco/mujoco.dart';

import 'backend/python.dart';

@internal
final pythonApi = PythonApi();

BaseApi _api = pythonApi;
@internal
BaseApi get api => _api;

@internal
abstract interface class BaseApi {
  MujocoViewer MujocoViewer_launch_passive(MjModel model, MjData data);
}

abstract interface class MujocoViewer {
  factory launch_passive(MjModel model, MjData data) => api.MujocoViewer_launch_passive(model, data);

  bool get is_running;
  void sync();
  void close();
  void dispose();
}