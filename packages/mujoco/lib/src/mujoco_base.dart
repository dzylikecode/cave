import 'backend/backend_factory.dart';
import 'data.dart';
import 'model.dart';

abstract final class Mujoco {
  static String get version => mujocoBackend.version;
}

void mjForward(MjModel model, MjData data) =>
    mujocoBackend.forward(modelHandle(model), dataHandle(data));

void mjStep(MjModel model, MjData data) =>
    mujocoBackend.step(modelHandle(model), dataHandle(data));

void mjResetData(MjModel model, MjData data) =>
    mujocoBackend.resetData(modelHandle(model), dataHandle(data));
