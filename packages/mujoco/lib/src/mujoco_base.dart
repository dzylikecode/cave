import 'backend/backend.dart';
import 'backend/backend_factory.dart' as backend;
import 'data.dart';
import 'model.dart';

Mujoco get mujoco => backend.mujoco;

void mjForward(MjModel model, MjData data) => mujoco.forward(model, data);

void mjStep(MjModel model, MjData data) => mujoco.step(model, data);

void mjResetData(MjModel model, MjData data) => mujoco.resetData(model, data);
