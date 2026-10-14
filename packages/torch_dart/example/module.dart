import 'package:py_embed/py_embed.dart' show using;
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

void main() => using((scope) {
  final model = Model();
  // Children are registered first so the parent is released before them.
  scope.defer(model.layer.dispose);
  scope.defer(model.dispose);

  final params = model.parameters();
  for (final param in params) {
    scope.defer(param.dispose);
  }
  final optimizer = optim.SGD(params, lr: 0.01);
  scope.defer(optimizer.dispose);

  final input = torch.tensor([
    [1.0, 2.0],
  ]);
  scope.defer(input.dispose);
  optimizer.zero_grad();
  final output = model([input]);
  scope.defer(output.dispose);
  final loss = output.pow(2);
  scope.defer(loss.dispose);
  final scalar = loss.mean();
  scope.defer(scalar.dispose);

  scalar.backward();
  optimizer.step();
  print('loss: ${scalar.item()}');
});
