import 'dart:io';

import 'package:py_embed/py_embed.dart' show ResourceScope, PyException;
import 'package:test/test.dart';
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/torch_dart.dart';

class ExportModel extends nn.Module {
  late final nn.Linear layer;
  ExportModel() {
    layer = register_module('layer', nn.Linear(2, 1));
  }
  @override
  Tensor forward(
    List<Tensor> inputs, {
    Map<String, Tensor> kwargs = const {},
  }) => layer(inputs);
}

void main() {
  test('save_pt reloads a Dart model and restores mixed training modes', () {
    ResourceScope.scope(() {
      final dir = Directory.systemTemp.createTempSync('torch-export-test-');
      try {
        final model = ExportModel();

        model.layer.eval();
        final input = ones([1, 2]);

        final expected = model([input]);

        final path = '${dir.path}/model.pt';
        model.save_pt(path, inputs: [input]);
        expect(model.training, isTrue);
        expect(model.layer.training, isFalse);
        final loaded = jit.load(path);

        final actual = loaded(input);

        expect(actual.toList(), expected.toList());
        final after = model([input]);

        expect(after.toList(), expected.toList());
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  test('failed save restores forward and individual training flags', () {
    ResourceScope.scope(() {
      final dir = Directory.systemTemp.createTempSync('torch-export-fail-');
      try {
        final model = ExportModel();

        model.layer.eval();
        final input = ones([1, 2]);

        final expected = model([input]);

        expect(
          () => model.save_pt('${dir.path}/missing/model.pt', inputs: [input]),
          throwsA(isA<PyException>()),
        );
        expect(model.training, isTrue);
        expect(model.layer.training, isFalse);
        final after = model([input]);

        expect(after.toList(), expected.toList());
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  test(
    'save_pt supports native layers and rejects unsupported input counts',
    () {
      ResourceScope.scope(() {
        final dir = Directory.systemTemp.createTempSync('torch-export-native-');
        try {
          final model = nn.Linear(2, 1);

          final input = ones([1, 2]);

          expect(
            () => model.save_pt('${dir.path}/model.pt', inputs: []),
            throwsUnsupportedError,
          );
          model.save_pt('${dir.path}/model.pt', inputs: [input]);
          final loaded = jit.load('${dir.path}/model.pt');

          final expected = model([input]);

          final actual = loaded(input);

          expect(actual.toList(), expected.toList());
        } finally {
          dir.deleteSync(recursive: true);
        }
      });
    },
  );
}
