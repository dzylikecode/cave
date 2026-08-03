import '../data.dart';
import '../model.dart';

abstract interface class Mujoco {
  String get version;

  MjModel createModelFromXmlString(String xml);

  MjModel createModelFromXmlPath(String path);

  MjData createData(MjModel model);

  void forward(MjModel model, MjData data);

  void step(MjModel model, MjData data);

  void resetData(MjModel model, MjData data);
}
