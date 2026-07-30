import 'backend/backend.dart';
import 'backend/backend_factory.dart';

final class MjModel {
  final BackendModel _handle;

  MjModel._(this._handle);

  factory MjModel.fromXmlString(String content) =>
      MjModel._(mujocoBackend.createModelFromXmlString(content));

  int get nq => _handle.nq;
  int get nv => _handle.nv;
  int get nu => _handle.nu;

  void dispose() => _handle.dispose();
}

BackendModel modelHandle(MjModel model) => model._handle;
