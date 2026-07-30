import 'array.dart';
import 'backend/backend.dart';
import 'backend/backend_factory.dart';
import 'model.dart';

final class MjData {
  final MjModel model;

  final BackendData _handle;

  MjData._(this.model, this._handle);

  factory MjData(MjModel model) =>
      ._(model, mujocoBackend.createData(modelHandle(model)));

  double get time => _handle.time;
  MjDoubleArray get qpos => _handle.qpos;
  MjDoubleArray get qvel => _handle.qvel;
  MjDoubleArray get qacc => _handle.qacc;
  MjDoubleArray get ctrl => _handle.ctrl;

  void dispose() => _handle.dispose();
}

BackendData dataHandle(MjData data) => data._handle;
