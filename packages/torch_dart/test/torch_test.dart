import 'package:test/test.dart';
import 'package:torch_dart/torch.dart';

void main() {
  test('creates and calculates tensors', () {
    final a = tensor([
      [1.0, 2.0],
      [3.0, 4.0],
    ]);
    final b = ones([2, 2]);
    final added = a + b;
    final result = added.matmul(b);

    try {
      expect(a.shape, [2, 2]);
      expect(a.numel, 4);
      expect(result.toList(), [
        [5.0, 5.0],
        [9.0, 9.0],
      ]);
    } finally {
      result.dispose();
      added.dispose();
      b.dispose();
      a.dispose();
    }
  });

  test('supports reshape and reductions', () {
    final values = arange(6, dtype: 'float64');
    final matrix = values.reshape([2, 3]);
    final mean = matrix.mean();

    try {
      expect(matrix.shape, [2, 3]);
      expect(mean.item(), 2.5);
    } finally {
      mean.dispose();
      matrix.dispose();
      values.dispose();
    }
  });
}
