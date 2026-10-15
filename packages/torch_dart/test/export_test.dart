import 'dart:io';

import 'package:py_embed/py_embed.dart' show using, PyException;
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
    using((scope) {
      final dir = Directory.systemTemp.createTempSync('torch-export-test-');
      scope.defer(() => dir.deleteSync(recursive: true));
      final model = ExportModel();
      scope.defer(model.layer.dispose);
      scope.defer(model.dispose);
      model.layer.eval();
      final input = ones([1, 2]);
      scope.defer(input.dispose);
      final expected = model([input]);
      scope.defer(expected.dispose);
      final path = '${dir.path}/model.pt';
      model.save_pt(path, inputs: [input]);
      expect(model.training, isTrue);
      expect(model.layer.training, isFalse);
      final loaded = jit.load(path);
      scope.defer(loaded.dispose);
      final actual = loaded(input);
      scope.defer(actual.dispose);
      expect(actual.toList(), expected.toList());
      final after = model([input]);
      scope.defer(after.dispose);
      expect(after.toList(), expected.toList());
    });
  });

  test('failed save restores forward and individual training flags', () {
    using((scope) {
      final dir = Directory.systemTemp.createTempSync('torch-export-fail-');
      scope.defer(() => dir.deleteSync(recursive: true));
      final model = ExportModel();
      scope.defer(model.layer.dispose);
      scope.defer(model.dispose);
      model.layer.eval();
      final input = ones([1, 2]);
      scope.defer(input.dispose);
      final expected = model([input]);
      scope.defer(expected.dispose);
      expect(
        () => model.save_pt('${dir.path}/missing/model.pt', inputs: [input]),
        throwsA(isA<PyException>()),
      );
      expect(model.training, isTrue);
      expect(model.layer.training, isFalse);
      final after = model([input]);
      scope.defer(after.dispose);
      expect(after.toList(), expected.toList());
    });
  });

  test(
    'save_pt supports native layers and rejects unsupported input counts',
    () {
      using((scope) {
        final dir = Directory.systemTemp.createTempSync('torch-export-native-');
        scope.defer(() => dir.deleteSync(recursive: true));
        final model = nn.Linear(2, 1);
        scope.defer(model.dispose);
        final input = ones([1, 2]);
        scope.defer(input.dispose);
        expect(
          () => model.save_pt('${dir.path}/model.pt', inputs: []),
          throwsUnsupportedError,
        );
        model.save_pt('${dir.path}/model.pt', inputs: [input]);
        final loaded = jit.load('${dir.path}/model.pt');
        scope.defer(loaded.dispose);
        final expected = model([input]);
        scope.defer(expected.dispose);
        final actual = loaded(input);
        scope.defer(actual.dispose);
        expect(actual.toList(), expected.toList());
      });
    },
  );
}
