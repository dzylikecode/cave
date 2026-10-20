import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';
import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

const xml =
    '<mujoco><worldbody><body><joint/><geom type="sphere" size="0.1" mass="1"/></body></worldbody></mujoco>';
void main() {
  test('native models are rejected before trying to open a window', () {
    Mujoco.useNativeApi = true;
    final model = MjModel.from_xml_string(xml);
    final data = MjData(model);
    try {
      expect(
        () => MujocoViewer.launch_passive(model, data),
        throwsA(isA<TypeError>()),
      );
    } finally {
      data.dispose();
      model.dispose();
    }
  });
  test('each covariant parameter enforces the Python backend type', () {
    Mujoco.useNativeApi = true;
    final nativeModel = MjModel.from_xml_string(xml);
    final nativeData = MjData(nativeModel);
    Mujoco.useNativeApi = false;
    final pythonModel = MjModel.from_xml_string(xml);
    final pythonData = MjData(pythonModel);
    try {
      expect(
        () => MujocoViewer.launch_passive(nativeModel, pythonData),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => MujocoViewer.launch_passive(pythonModel, nativeData),
        throwsA(isA<TypeError>()),
      );
      final otherModel = MjModel.from_xml_string(xml);
      try {
        expect(
          () => MujocoViewer.launch_passive(otherModel, pythonData),
          throwsArgumentError,
        );
      } finally {
        otherModel.dispose();
      }
    } finally {
      pythonData.dispose();
      pythonModel.dispose();
      nativeData.dispose();
      nativeModel.dispose();
    }
  });
  test('passive viewer locks, closes and releases ownership safely', () {
    // Exercise the real Python interop using a deterministic window handle.
    // GUI startup is checked separately against the actual desktop display.
    runString('''
import mujoco.viewer as _viewer
_original_launch = _viewer.launch_passive
class _FakeLock:
    def __enter__(self):
        _viewer.test_depth += 1
    def __exit__(self, *args):
        _viewer.test_depth -= 1
class _FakeViewer:
    def is_running(self): return True
    def lock(self): return _FakeLock()
    def sync(self):
        assert _viewer.test_depth == 0
    def close(self):
        _viewer.test_closes += 1
_viewer.test_depth = 0
_viewer.test_closes = 0
_viewer.launch_passive = lambda m, d: _FakeViewer()
''');
    Mujoco.useNativeApi = false;
    final model = MjModel.from_xml_string(xml);
    final data = MjData(model);
    final viewer = MujocoViewer.launch_passive(model, data);
    try {
      expect(viewer.is_running, isTrue);
      expect(viewer.withLock(() => 42), 42);
      expect(
        () => viewer.withLock<void>(() => throw StateError('test')),
        throwsStateError,
      );
      ResourceScope.scope(() {
        final module = PyModule('mujoco.viewer');
        expect(module.getAttrInt('test_depth'), 0);
      });
      viewer.sync();
      viewer.dispose();
      viewer.close();
      viewer.dispose();
      expect(viewer.isDisposed, isTrue);
      expect(viewer.is_running, isFalse);
      expect(model.isDisposed, isFalse);
      expect(data.isDisposed, isFalse);
      expect(() => viewer.sync(), throwsStateError);
      ResourceScope.scope(() {
        final module = PyModule('mujoco.viewer');
        expect(module.getAttrInt('test_closes'), 1);
      });
    } finally {
      viewer.dispose();
      data.dispose();
      model.dispose();
      runString(
        'import mujoco.viewer as _viewer; _viewer.launch_passive = _original_launch',
      );
    }
  });
}
