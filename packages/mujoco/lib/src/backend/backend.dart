import '../array.dart';

abstract interface class MujocoBackend {
  String get version;

  BackendModel createModelFromXmlString(String xml);

  BackendModel createModelFromXmlPath(String path);

  BackendData createData(BackendModel model);

  void forward(BackendModel model, BackendData data);

  void step(BackendModel model, BackendData data);

  void resetData(BackendModel model, BackendData data);
}

abstract interface class BackendModel {
  int get nq;
  int get nv;
  int get nu;

  void dispose();
}

abstract interface class BackendData {
  double get time;
  MjDoubleArray get qpos;
  MjDoubleArray get qvel;
  MjDoubleArray get qacc;
  MjDoubleArray get ctrl;

  void dispose();
}
