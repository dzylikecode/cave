import 'package:py_embed/py_embed.dart' show PyException;
import 'package:test/test.dart';
import 'package:torch_dart/optim.dart' as optim;
import 'package:torch_dart/torch_dart.dart';

void main() {
  test('Adam updates parameters across steps and clears gradients', () {
    final weight = tensor(2.0, requires_grad: true);
    final optimizer = optim.Adam([weight], lr: 0.1);
    try {
      for (var i = 0; i < 3; i++) {
        optimizer.zero_grad();
        expect(weight.grad, isNull);
        final loss = weight * 2;
        try {
          loss.backward();
          optimizer.step();
        } finally {
          loss.dispose();
        }
      }
      expect(weight.item(), closeTo(1.7, 1e-6));
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

  test('Adam forwards betas, epsilon, weight decay and AMSGrad', () {
    final weight = tensor(2.0, requires_grad: true);
    final optimizer = optim.Adam(
      [weight],
      lr: 0.1,
      betas: [0, 0],
      eps: 1,
      weight_decay: 0.5,
      amsgrad: true,
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
      // Gradients including decay: 5, then 115/24. AMSGrad keeps sqrt(v)=5.
      expect(weight.item(), closeTo(529 / 288, 1e-6));
    } finally {
      optimizer.dispose();
      weight.dispose();
    }
  });

  test('PyTorch validates Adam options', () {
    final weight = tensor(2.0, requires_grad: true);
    try {
      expect(() => optim.Adam([weight], lr: -1), throwsA(isA<PyException>()));
      expect(
        () => optim.Adam([weight], betas: [1, 0.999]),
        throwsA(isA<PyException>()),
      );
      expect(() => optim.Adam([weight], eps: -1), throwsA(isA<PyException>()));
    } finally {
      weight.dispose();
    }
  });
}
