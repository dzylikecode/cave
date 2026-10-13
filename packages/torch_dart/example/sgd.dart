import 'package:torch_dart/optim.dart' as optim;
import 'package:torch_dart/torch_dart.dart' as torch;

void main() {
  final weight = torch.tensor(2.0, requires_grad: true);
  final optimizer = optim.SGD([weight], lr: 0.1);
  try {
    for (var i = 0; i < 10; i++) {
      optimizer.zero_grad();
      final loss = weight.pow(2);
      try {
        loss.backward();
        optimizer.step();
        print('loss: ${loss.item()}, weight: ${weight.item()}');
      } finally {
        loss.dispose();
      }
    }
  } finally {
    optimizer.dispose();
    weight.dispose();
  }
}
