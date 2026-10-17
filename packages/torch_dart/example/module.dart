import 'package:py_embed/py_embed.dart' show ResourceScope;
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/optim.dart' as optim;
import 'package:torch_dart/torch_dart.dart' as torch;

class Model extends nn.Module {
  late final nn.Linear layer;
  Model() {
    layer = register_module('layer', nn.Linear(2, 1));
  }
  @override
  torch.Tensor forward(
    List<torch.Tensor> inputs, {
    Map<String, torch.Tensor> kwargs = const {},
  }) => layer(inputs);
}

void main() => ResourceScope.scope(() {
  final model = Model();
  // Python resources are released automatically when this scope ends.

  final params = model.parameters();

  final optimizer = optim.SGD(params, lr: 0.01);

  final input = torch.tensor([
    [1.0, 2.0],
  ]);

  optimizer.zero_grad();
  final output = model([input]);

  final loss = output.pow(2);

  final scalar = loss.mean();

  scalar.backward();
  optimizer.step();
  print('loss: ${scalar.item()}');
});
