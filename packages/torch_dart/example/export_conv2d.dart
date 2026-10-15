import 'dart:convert';
import 'dart:io';

import 'package:py_embed/py_embed.dart' show using;
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/torch_dart.dart' as torch;

class Model extends nn.Module {
  late final nn.Conv2d conv1;
  late final nn.Conv2d conv2;
  Model() {
    conv1 = register_module('conv1', nn.Conv2d(1, 20, 5));
    conv2 = register_module('conv2', nn.Conv2d(20, 20, 5));
  }

  @override
  torch.Tensor forward(
    List<torch.Tensor> inputs, {
    Map<String, torch.Tensor> kwargs = const {},
  }) => using((scope) {
    final a = conv1(inputs);
    scope.defer(a.dispose);
    final b = a.relu();
    scope.defer(b.dispose);
    final c = conv2([b]);
    scope.defer(c.dispose);
    return c.relu();
  });
}

void main() => using((scope) {
  final model = Model();
  scope.defer(model.conv2.dispose);
  scope.defer(model.conv1.dispose);
  scope.defer(model.dispose);
  final input = torch.randn([1, 1, 28, 28]);
  scope.defer(input.dispose);
  final directory = Directory.systemTemp.createTempSync('torch-dart-conv2d-');
  final path = '${directory.path}/model.pt';

  // The complete public export API.
  model.save_pt(path, inputs: [input]);

  final fixtures = <Map<String, Object>>[];
  for (final shape in [
    [1, 1, 28, 28],
    [2, 1, 28, 28],
    [1, 1, 32, 32],
  ]) {
    using((inner) {
      final x = torch.randn(shape);
      inner.defer(x.dispose);
      final y = model([x]);
      inner.defer(y.dispose);
      fixtures.add({'input': x.toList(), 'expected': y.toList()});
    });
  }
  File('${directory.path}/fixtures.json')
      .writeAsStringSync(jsonEncode(fixtures));

  // Load in a fresh process without any Dart callback or model class.
  final verification = Process.runSync('python', [
    '-c',
    '''
import json, sys, torch
model = torch.jit.load(sys.argv[1]).eval()
with open(sys.argv[2]) as f:
    fixtures = json.load(f)
with torch.no_grad():
    for index, case in enumerate(fixtures):
        x, expected = torch.tensor(case['input']), torch.tensor(case['expected'])
        actual = model(x)
        diff = (actual - expected).abs().max().item()
        assert torch.allclose(actual, expected, rtol=1e-5, atol=1e-6)
        print(f'case {index}: shape={tuple(actual.shape)}, max_diff={diff}')
print('Independent Python process: PASS')
''',
    path,
    '${directory.path}/fixtures.json',
  ]);
  stdout.write(verification.stdout);
  if (verification.exitCode != 0) {
    throw StateError('Reload verification failed: ${verification.stderr}');
  }
  print('Saved model: $path');
});
