// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:io';

import 'package:mujoco/mujoco.dart';
import 'package:mujoco/src/backend/python.dart';
import 'package:mujoco_viewer/src/backend/python.dart';
import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';
import 'package:torch_dart/torch_dart.dart' as torch;

const modelXml = '''
<mujoco><worldbody><body><joint name="hinge" type="hinge"/>
<geom type="sphere" size="0.1" mass="1"/></body></worldbody>
<sensor><jointpos name="angle" joint="hinge"/></sensor></mujoco>
''';

void main() {
  group(
    'py_embed 0.4 scope compatibility',
    () {
      test('MuJoCo reads and writes arrays and sensor views', () {
        Mujoco.useNativeApi = false;
        final model = MjModel.from_xml_string(modelXml);
        final data = MjData(model);
        try {
          data.qpos[0] = 0.4;
          mj_forward(model, data);
          expect(data.qpos[0], closeTo(0.4, 1e-12));
          expect(model.sensor('angle').name, 'angle');
          expect(model.sensor('angle').dim, 1);
          expect(data.sensor('angle').data[0], closeTo(0.4, 1e-12));
          data.sensor('angle').data[0] = 0.5;
          expect(data.sensordata.toList(), [0.5]);
          mj_step(model, data);
          expect(data.time, greaterThan(0));
        } finally {
          data.dispose();
          model.dispose();
        }
      });

      test('Viewer wrapper releases temporary Python method results', () {
        final model = MjModel.from_xml_string(modelXml) as MjModelPython;
        final data = MjData(model) as MjDataPython;
        // Exercise the wrapper without opening a GUI.
        runString('''
import types
_scope_viewer = types.SimpleNamespace(
    is_running=lambda: True, sync=lambda: None, close=lambda: None)
''');
        final handle = Py.using((scope) {
          final main = scope(PyModule('__main__'));
          return main.getAttr('_scope_viewer');
        });
        final viewer = MujocoViewerPython(handle, model, data);
        try {
          expect(viewer.is_running, isTrue);
          viewer.sync();
          viewer.close();
        } finally {
          viewer.dispose();
          data.dispose();
          model.dispose();
        }
      });

      test(
        'Torch metadata, JIT loading and inference survive scope cleanup',
        () {
          final directory = Directory.systemTemp.createTempSync('cave-scope-');
          final path = '${directory.path}/identity.pt';
          runString('''
import torch
_scope_model = torch.jit.trace(torch.nn.Identity(), torch.zeros(2, 3))
_scope_model.save(${jsonEncode(path)})
''');
          try {
            final model = torch.jit.load(path, map_location: .new(.cpu))
              ..eval();
            final input = torch.zeros(
              [2, 3],
              dtype: .float32,
              device: .new(.cpu),
            );
            try {
              expect(input.shape, [2, 3]);
              expect(input.dtype, torch.DType.float32);
              expect(input.device, torch.Device(torch.DeviceType.cpu));
              final output = torch.inference_mode(() => model(input));
              try {
                expect(output.shape, [2, 3]);
              } finally {
                output.dispose();
              }
              expect(() => model.forward([]), throwsA(isA<PyException>()));
              // A failed call must leave the input and model usable.
              final second = model(input);
              try {
                expect(second.dtype, torch.DType.float32);
              } finally {
                second.dispose();
              }
              expect(
                () =>
                    torch.inference_mode<void>(() => throw StateError('stop')),
                throwsStateError,
              );
              final active = Py.using((scope) {
                final module = scope(PyModule('torch'));
                final check = scope(
                  module.getAttr('is_inference_mode_enabled'),
                );
                return scope(check.call0()).asBool();
              });
              expect(active, isFalse);
            } finally {
              input.dispose();
              model.dispose();
            }
          } finally {
            directory.deleteSync(recursive: true);
          }
        },
      );
    },
    skip: Platform.environment['CAVE_PYTHON_TEST'] != '1'
        ? 'Set CAVE_PYTHON_TEST=1 with MuJoCo and Torch installed.'
        : false,
  );
}
