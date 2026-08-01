import 'backend/backend_factory.dart';
import 'data.dart';
import 'model.dart';

abstract final class Mujoco {
  static String get version => mujocoBackend.version;
}

void mjForward(MjModel model, MjData data) =>
    mujocoBackend.forward(model.backendHandle, data.backendHandle);

void mjStep(MjModel model, MjData data) =>
    mujocoBackend.step(model.backendHandle, data.backendHandle);

void mjResetData(MjModel model, MjData data) =>
    mujocoBackend.resetData(model.backendHandle, data.backendHandle);
