import 'package:py_embed/py_embed.dart';
import 'package:mujoco/mujoco.dart';

void main() async {
  final py = Python.venv(await getPyExecutableFromShell());
  print('mujoco version: ${Mujoco.version}');
  py.dispose();
}
