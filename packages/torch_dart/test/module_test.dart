import 'package:test/test.dart';
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/optim.dart' as optim;
import 'package:torch_dart/torch_dart.dart';

class Model extends nn.Module {
  late final nn.Linear layer;
  Model() {
    layer = register_module('layer', nn.Linear(2, 1));
  }
  @override
  Tensor forward(List<Tensor> inputs, {Map<String, Tensor> kwargs = const {}}) {
    final result = layer(inputs);
    if (kwargs.isEmpty) return result;
    try {
      return result * kwargs['scale']!;
    } finally {
      result.dispose();
    }
  }
}

class Identity extends nn.Module {
  @override
  Tensor forward(
    List<Tensor> inputs, {
    Map<String, Tensor> kwargs = const {},
  }) => inputs.isEmpty ? kwargs['x']! : inputs.single;
}

void main() {
  test(
    'registered Linear parameters train through Dart forward and kwargs',
    () {
      manual_seed(42);
      final model = Model();
      final params = model.parameters();
      final optimizer = optim.SGD(params, lr: 0.01);
      final input = tensor([
        [1.0, 2.0],
      ]);
      final scale = tensor(2.0);
      try {
        expect(params.length, 2);
        expect(model.eval(), same(model));
        expect(model.training, isFalse);
        expect(model.layer.training, isFalse);
        model.train();
        expect(model.layer.training, isTrue);
        final output = model([input], kwargs: {'scale': scale});
        final loss = output.sum();
        try {
          loss.backward();
          final grad = params.first.grad!;
          try {
            expect(grad.toList(), [
              [2.0, 4.0],
            ]);
          } finally {
            grad.dispose();
          }
          optimizer.step();
          model.zero_grad();
          expect(params.first.grad, isNull);
        } finally {
          loss.dispose();
          output.dispose();
        }
      } finally {
        optimizer.dispose();
        for (final param in params) {
          param.dispose();
        }
        input.dispose();
        scale.dispose();
        model.dispose();
        model.layer.dispose();
      }
    },
  );

  test(
    'returning an input retains ownership for positional and keyword calls',
    () {
      final model = Identity();
      final input = tensor([3.0]);
      try {
        for (final output in [
          model([input]),
          model([], kwargs: {'x': input}),
        ]) {
          expect(output.toList(), [3.0]);
          output.dispose();
        }
        expect(input.toList(), [3.0]);
      } finally {
        input.dispose();
        model.dispose();
      }
    },
  );
}
