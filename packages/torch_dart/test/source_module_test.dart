import 'dart:io';

import 'package:py_embed/py_embed.dart' as py;
import 'package:test/test.dart';
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/torch_dart.dart' as torch;

const source = '''
import torch.nn as nn
class Model(nn.Module):
    def __init__(self, width=2, *, bias=True):
        super().__init__()
        self.layer = nn.Linear(width, 1, bias=bias)
    def forward(self, x):
        return self.layer(x).relu()
''';

void main() {
  test(
    'source model constructor, parameters, forward and TorchScript export',
    () {
      py.using((scope) {
        final dir = Directory.systemTemp.createTempSync('torch-source-');
        scope.defer(() => dir.deleteSync(recursive: true));
        final model = nn.Module.fromSource(
          source,
          args: [3],
          kwargs: {'bias': false},
        );
        scope.defer(model.dispose);
        final params = model.parameters();
        for (final param in params) {
          scope.defer(param.dispose);
        }
        expect(params.length, 1);
        expect(params.single.shape, [1, 3]);
        final input = torch.ones([1, 3]);
        scope.defer(input.dispose);
        final expected = model([input]);
        scope.defer(expected.dispose);
        expect(expected.shape, [1, 1]);
        model.save_pt('${dir.path}/graph.pt', inputs: [input]);
        final loaded = torch.jit.load('${dir.path}/graph.pt');
        scope.defer(loaded.dispose);
        final actual = loaded(input);
        scope.defer(actual.dispose);
        expect(actual.toList(), expected.toList());
      });
    },
  );

  test('named source model can be pickled without an example input', () {
    py.using((scope) {
      final dir = Directory.systemTemp.createTempSync('torch-pickle-');
      scope.defer(() => dir.deleteSync(recursive: true));
      final model = nn.Module.fromSource(source, name: '_torch_source_test');
      scope.defer(model.dispose);
      final path = '${dir.path}/model.pt';
      torch.save(model, path);
      final torchPy = scope(py.PyModule('torch'));
      final load = scope(torchPy.getAttr('load'));
      // Explicitly allow pickle on versions which support weights_only.
      final inspect = scope(py.PyModule('inspect'));
      final signature = scope(
        scope(inspect.getAttr('signature')).forward([load]),
      );
      final parameters = scope(signature.getAttr('parameters'));
      final contains = scope(parameters.getAttr('__contains__'));
      final hasWeightsOnly = scope(contains.forward(['weights_only'])).asBool();
      final restored = scope(
        load.forward(
          [path],
          kwargs: {if (hasWeightsOnly) 'weights_only': false},
        ),
      );
      final input = torch.ones([1, 2]);
      scope.defer(input.dispose);
      final output = model([input]);
      scope.defer(output.dispose);
      final actual = scope(restored.forward([input]));
      final values = scope(scope(actual.getAttr('tolist')).call0());
      expect(values.toString(), output.toList().toString());
    });
  });
}
