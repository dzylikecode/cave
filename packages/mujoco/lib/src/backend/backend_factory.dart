import 'backend.dart';
import 'python/backend.dart';

Mujoco? _mujoco;

Mujoco get mujoco => _mujoco ??= createMujoco();

Mujoco createMujoco() => MujocoPython();
