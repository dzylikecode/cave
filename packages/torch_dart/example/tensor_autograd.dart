import 'package:torch_dart/torch_dart.dart' as torch;

void main() {
  final owned = <torch.Tensor>[];
  torch.Tensor own(torch.Tensor value) {
    owned.add(value);
    return value;
  }

  try {
    final weight = own(torch.tensor([2.0, 3.0], requires_grad: true));
    final squared = own(weight.pow(2));
    final loss = own(squared.mean());
    loss.backward();
    final gradient = own(weight.grad!);

    print('loss: ${loss.item()}');
    print('gradient: ${gradient.toList()}');

    torch.no_grad(() => weight.add_(gradient, alpha: -0.1));
    weight.zero_grad();
    print('updated weight: ${weight.toList()}');
  } finally {
    for (final value in owned.reversed) {
      value.dispose();
    }
  }
}
