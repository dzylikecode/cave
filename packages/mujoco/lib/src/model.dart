import 'backend/backend.dart';
import 'backend/backend_factory.dart';

final class MjModel {
  final BackendModel _handle;

  MjModel._(this._handle);

  factory MjModel.fromXmlString(String content) =>
      ._(mujocoBackend.createModelFromXmlString(content));
  factory MjModel.fromXmlPath(String filePath) =>
      ._(mujocoBackend.createModelFromXmlPath(filePath));

  BackendModel get backendHandle => _handle;

  int get nq => _handle.nq;
  int get nv => _handle.nv;
  int get nu => _handle.nu;

  void dispose() => _handle.dispose();
}
