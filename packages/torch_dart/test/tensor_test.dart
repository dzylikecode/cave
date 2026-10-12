import 'package:test/test.dart';
import 'package:torch_dart/torch_dart.dart';

void main() {
  test('dtype', () {
    final x = zeros([2, 3]);  expect(x.shape, [2, 3]);
                              expect(x.dtype, DType.float32);
  });
}