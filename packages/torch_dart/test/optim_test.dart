import 'package:py_embed/py_embed.dart' show PyException;
import 'package:test/test.dart';
import 'package:torch_dart/optim.dart' as optim;
import 'package:torch_dart/torch_dart.dart';

void main() {
  test('SGD optimizes a leaf and clears gradients', () {
    final weight = tensor(2.0, requires_grad: true);
    final optimizer = optim.SGD([weight], lr: 0.1);
    try {
      for (var i = 0; i < 3; i++) {
        optimizer.zero_grad();
        expect(weight.grad, isNull);
        final loss = weight.pow(2);
        try {
          loss.backward();
          optimizer.step();
        } finally {
          loss.dispose();
        }
      }
      expect(weight.item(), closeTo(1.024, 1e-6));
      expect(weight.requires_grad, isTrue);
      optimizer.zero_grad(set_to_none: false);
      final gradient = weight.grad!;
      try {
        expect(gradient.item(), 0.0);
      } finally {
        gradient.dispose();
      }
      optimizer.zero_grad();
      expect(weight.grad, isNull);
    } finally {
      optimizer.dispose();
      weight.dispose();
    }
  });

  test('momentum and weight decay persist across steps', () {
    final weight = tensor(2.0, requires_grad: true);
    final optimizer = optim.SGD(
      [weight],
      lr: 0.1,
      momentum: 0.9,
      weight_decay: 0.5,
    );
    try {
      for (var i = 0; i < 2; i++) {
        optimizer.zero_grad();
        final loss = weight.pow(2);
        try {
          loss.backward();
          optimizer.step();
        } finally {
          loss.dispose();
        }
      }
      // First: 2 - .1 * 5 = 1.5. Second momentum: .9 * 5 + 3.75 = 8.25.
      expect(weight.item(), closeTo(0.675, 1e-6));
    } finally {
      optimizer.dispose();
      weight.dispose();
    }
  });

  test('PyTorch validates SGD options', () {
    final weight = tensor(2.0, requires_grad: true);
    try {
      expect(() => optim.SGD([weight], lr: -1), throwsA(isA<PyException>()));
      expect(
        () => optim.SGD([weight], nesterov: true),
        throwsA(isA<PyException>()),
      );
      expect(() => optim.SGD([]), throwsA(isA<PyException>()));
    } finally {
      weight.dispose();
    }
  });
}
