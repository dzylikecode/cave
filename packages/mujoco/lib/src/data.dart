import 'array.dart';
import 'backend/backend_factory.dart';
import 'model.dart';
import 'sensor.dart';

abstract interface class MjData {
  factory MjData(MjModel model) => mujoco.createData(model);

  MjModel get model;

  double get time;
  MjDoubleArray get qpos;
  MjDoubleArray get qvel;
  MjDoubleArray get qacc;
  MjDoubleArray get ctrl;
  MjSensor sensor(String name);

  void dispose();
}
