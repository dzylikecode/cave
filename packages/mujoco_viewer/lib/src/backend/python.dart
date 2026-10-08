// ignore_for_file: non_constant_identifier_names, implementation_imports
import 'package:py_embed/py_embed.dart';
import 'package:mujoco/src/backend/python.dart';

import '../base.dart';

final class PythonApi() implements BaseApi {
  final _mujoco_viewer = PyModule('mujoco.viewer');

  late final _MujocoViewer_launch_passive = _mujoco_viewer.getAttr(
    'launch_passive',
  );

  @override
  MujocoViewerPython MujocoViewer_launch_passive(
    covariant MjModelPython model,
    covariant MjDataPython data,
  ) {
    model.handle.ref.increment();
    data.handle.ref.increment();
    final h = _MujocoViewer_launch_passive.callN([model.handle, data.handle]);
    return MujocoViewerPython(h, model, data);
  }
}

class MujocoViewerPython(
  final PyObject handle,
  final MjModelPython model,
  final MjDataPython data,
) implements MujocoViewer {
  @override
  bool get is_running => Py.using((scope) {
    final method = scope(handle.getAttr('is_running'));
    return scope(method.call0()).asBool();
  });

  @override
  void sync() => Py.using((scope) {
    final method = scope(handle.getAttr('sync'));
    scope(method.call0());
  });

  @override
  void close() => Py.using((scope) {
    final method = scope(handle.getAttr('close'));
    scope(method.call0());
  });

  @override
  void dispose() => handle.ref.discrement();
}
