import 'dart:io';

import 'package:py_embed/py_embed.dart' show using;
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/torch_dart.dart' as torch;

void main() => using((scope) {
  final model = nn.Module.fromSource('''
import torch.nn as nn

class Model(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 20, 5)
        self.conv2 = nn.Conv2d(20, 20, 5)

    def forward(self, x):
        return self.conv2(self.conv1(x).relu()).relu()
''', name: 'my_model');
  scope.defer(model.dispose);

  final directory = Directory.systemTemp.createTempSync('torch-source-model-');
  // Whole-model pickle: no input needed. Loading needs my_model.Model again.
  final path = '${directory.path}/model.pt';
  torch.save(model, path);
  print('Whole Python model: $path');

  final input = torch.ones([1, 1, 28, 28]);
  scope.defer(input.dispose);
  final output = model([input]);
  scope.defer(output.dispose);
  print('Output shape: ${output.shape}');

  // Standalone TorchScript: requires a representative example input.
  final graphPath = '${directory.path}/graph.pt';
  model.save_pt(graphPath, inputs: [input]);
  final loaded = torch.jit.load(graphPath);
  scope.defer(loaded.dispose);
  final restored = loaded(input);
  scope.defer(restored.dispose);
  print(
    'Reloaded graph matches: ${restored.toList().toString() == output.toList().toString()}',
  );
});
