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
      py.ResourceScope.scope(() {
        final dir = Directory.systemTemp.createTempSync('torch-source-');
        try {
          final model = nn.Module.fromSource(
            source,
            args: [3],
            kwargs: {'bias': false},
          );

          final params = model.parameters();

          expect(params.length, 1);
          expect(params.single.shape, [1, 3]);
          final input = torch.ones([1, 3]);

          final expected = model([input]);

          expect(expected.shape, [1, 1]);
          model.save_pt('${dir.path}/graph.pt', inputs: [input]);
          final loaded = torch.jit.load('${dir.path}/graph.pt');

          final actual = loaded(input);

          expect(actual.toList(), expected.toList());
        } finally {
          dir.deleteSync(recursive: true);
        }
      });
    },
  );

  test('named source model can be pickled without an example input', () {
    py.ResourceScope.scope(() {
      final dir = Directory.systemTemp.createTempSync('torch-pickle-');
      try {
        final model = nn.Module.fromSource(source, name: '_torch_source_test');

        final path = '${dir.path}/model.pt';
        torch.save(model, path);
        final torchPy = py.PyModule('torch');
        final load = torchPy.getAttr('load');
        // Explicitly allow pickle on versions which support weights_only.
        final inspect = py.PyModule('inspect');
        final signature = inspect.getAttr('signature').forward([load]);
        final parameters = signature.getAttr('parameters');
        final contains = parameters.getAttr('__contains__');
        final hasWeightsOnly = contains.forward(['weights_only']).asBool();
        final restored = load.forward(
          [path],
          kwargs: {if (hasWeightsOnly) 'weights_only': false},
        );
        final input = torch.ones([1, 2]);

        final output = model([input]);

        final actual = restored.forward([input]);
        final values = actual.getAttr('tolist').call0();
        expect(values.toString(), output.toList().toString());
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
