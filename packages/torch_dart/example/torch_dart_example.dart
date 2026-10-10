import 'package:torch_dart/torch_dart.dart' as torch;
import 'package:torch_dart/torch_dart.dart' show Torch;

void main() {
  print('PyTorch: ${Torch.version}');
  final x = torch.zeros([2, 3]);
  print(x);

  final y = torch.arange(12);
  print(y);

  final z = y.reshape([3, 4]);  
  print(z);
}
