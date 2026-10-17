// ignore_for_file: non_constant_identifier_names, implementation_imports
import 'package:py_embed/py_embed.dart';
import 'package:mujoco/src/backend/python.dart';

import '../base.dart';

final class PythonApi() implements BaseApi {
  final _mujoco_viewer = ResourceScope.unmanaged(
    () => PyModule('mujoco.viewer'),
  );

  late final _MujocoViewer_launch_passive = ResourceScope.unmanaged(
    () => _mujoco_viewer.getAttr('launch_passive'),
  );

  @override
  MujocoViewerPython MujocoViewer_launch_passive(
    covariant MjModelPython model,
    covariant MjDataPython data,
  ) {
    final h = _MujocoViewer_launch_passive.forward([model, data]);
    return MujocoViewerPython(h, model, data);
  }
}

class MujocoViewerPython(
  final PyObject handle,
  final MjModelPython model,
  final MjDataPython data,
) implements MujocoViewer {
  @override
  bool get is_running => ResourceScope.scope(() {
    final method = handle.getAttr('is_running');
    return method.call0().asBool();
  });

  @override
  void sync() => ResourceScope.scope(() {
    final method = handle.getAttr('sync');
    method.call0();
  });

  @override
  void close() => ResourceScope.scope(() {
    final method = handle.getAttr('close');
    method.call0();
  });

  @override
  void dispose() => handle.dispose();
}
