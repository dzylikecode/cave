import 'package:test/test.dart';
import 'package:torch_dart/functional.dart';
import 'package:torch_dart/torch_dart.dart';

void main() {
  test('indexing, stacking, clamping, and sample standard deviation', () {
    tensorScope(() {
      final x = tensor([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      expect(x.select(0, 1).toList(), [3.0, 4.0]);
      expect(x.narrow(1, 1, 1).toList(), [
        [2.0],
        [4.0],
      ]);
      expect(x.indexSelect(0, tensor([1, 0], dtype: DType.int64)).toList(), [
        [3.0, 4.0],
        [1.0, 2.0],
      ]);
      expect(stack([x, x]).shape, [2, 2, 2]);
      expect(cat([x, x], dim: 1).shape, [2, 4]);
      expect(x.clamp(2, 3).toList(), [
        [2.0, 2.0],
        [3.0, 3.0],
      ]);
      expect(x.std().item() as num, closeTo(1.2909944, 1e-6));
      expect(maximum(x, x * 2).toList(), [
        [2.0, 4.0],
        [6.0, 8.0],
      ]);
    });
  });
  test(
    'scopes promote outputs, keep persistent ownership, and retain autograd',
    () {
      final x = tensor([2.0], requires_grad: true);
      final output = tensorScope(() => keepTensor((x * 2).pow(2).sum()));
      final persistent = tensorScope(() => ownTensor(tensor([7.0])));
      try {
        expect(output.item(), 16.0);
        output.backward();
        tensorScope(() => expect(x.grad!.item(), 16.0));
        expect(clipGradNorm([x], 1), closeTo(16, 1e-6));
        tensorScope(() => expect(x.grad!.item() as num, closeTo(1, 1e-6)));
        expect(persistent.toList(), [7.0]);
      } finally {
        output.dispose();
        persistent.dispose();
        x.dispose();
      }
    },
  );
}
