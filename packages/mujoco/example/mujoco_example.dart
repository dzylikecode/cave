import 'package:mujoco/mujoco.dart';

void main() {
  print('MuJoCo version: ${Mujoco.version}');
  Mujoco.useNativeApi = true;
  print('MuJoCo version: ${Mujoco.version}');
}
