import 'backend/backend_factory.dart';

abstract interface class MjModel {
  factory MjModel.fromXmlString(String content) =>
      mujoco.createModelFromXmlString(content);

  factory MjModel.fromXmlPath(String filePath) =>
      mujoco.createModelFromXmlPath(filePath);

  int get nq;
  int get nv;
  int get nu;

  void dispose();
}
