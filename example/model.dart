import 'dart:io';

import 'package:py_embed/py_embed.dart';
import 'package:torch_dart/torch_dart.dart';

void main() {
  final modelPath = File.fromUri(
    Platform.script.resolve('../assets/models/lite_yuhan1.pt'),
  ).path;

  try {
    final model = torch.jit.load(modelPath, mapLocation: 'cpu')..eval();
    final input = zeros([1, 21 * 56], dtype: 'float32');
    final output = torch.inferenceMode(() => model(input));
    print('PyTorch ${torch.version}');
    print('model: $modelPath');
    print('input shape: ${input.shape}');
    print('output shape: ${output.shape}');
    print('actions: ${output.toList()}');
  } finally {
    Python.shutdown();
  }
}
