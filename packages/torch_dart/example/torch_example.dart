import 'package:py_embed/py_embed.dart';
import 'package:torch_dart/torch.dart';

void main() {
  manualSeed(42);
  final input = randn([2, 3]);
  final weights = ones([3, 1]);
  final output = input.matmul(weights).relu();

  try {
    print('PyTorch $torchVersion');
    print('shape: ${output.shape}');
    print(output.toList());
  } finally {
    Python.shutdown();
  }
}
