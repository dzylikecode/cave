import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

const xml = '''
<mujoco><worldbody><body><joint name="hinge" type="hinge"/>
<geom type="sphere" size="0.1" mass="1"/></body></worldbody>
<sensor><jointpos name="angle" joint="hinge"/></sensor></mujoco>
''';

void main() {
  for (final native in [false, true]) {
    group(native ? 'Native scopes' : 'Python scopes', () {
      setUp(() => Mujoco.useNativeApi = native);
      test('scope disposes owners', () {
        late MjModel model;
        late MjData data;
        late MjDoubleListView view;
        ResourceScope.scope(() {
          model = MjModel.from_xml_string(xml);
          data = MjData(model);
          view = data.qpos;
          view[0] = 0.4;
          mj_forward(model, data);
          expect(data.sensor('angle').data[0], closeTo(0.4, 1e-12));
        });
        expect(model.isDisposed, isTrue);
        expect(data.isDisposed, isTrue);
        data.dispose();
        model.dispose();
      });
      test('returning promotes data and its views', () {
        late MjData data;
        ResourceScope.scope(() {
          final model = MjModel.from_xml_string(xml);
          data = ResourceScope.returning(() => MjData(model));
          data.qpos[0] = 0.7;
          expect(data.qpos[0], closeTo(0.7, 1e-12));
          mj_step(model, data);
          expect(data.time, greaterThan(0));
        });
        expect(data.isDisposed, isTrue);
      });
      test('detached owners survive scope and dispose independently', () {
        late MjModel model;
        late MjData data;
        ResourceScope.scope(() {
          model = MjModel.from_xml_string(xml)..detachFromScope();
          data = MjData(model)..detachFromScope();
        });
        try {
          expect(model.isDisposed, isFalse);
          expect(data.isDisposed, isFalse);
          expect(data.qpos.toList(), [0.0]);
          data.dispose();
          data.dispose();
          expect(model.nq, 1);
        } finally {
          data.dispose();
          model.dispose();
        }
      });
      test('data can be disposed after its model', () {
        final model = MjModel.from_xml_string(xml);
        final data = MjData(model);
        model.dispose();
        data.dispose();
        expect(model.isDisposed, isTrue);
        expect(data.isDisposed, isTrue);
      });
      test('throwing scope cleans up both owners', () {
        late MjModel model;
        late MjData data;
        expect(
          () => ResourceScope.scope(() {
            model = MjModel.from_xml_string(xml);
            data = MjData(model);
            throw StateError('test');
          }),
          throwsStateError,
        );
        expect(model.isDisposed, isTrue);
        expect(data.isDisposed, isTrue);
      });
    });
  }
}
