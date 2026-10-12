import 'package:test/test.dart';
import 'package:torch_dart/torch_dart.dart';

void main() {
  test('dtype', () {
    // dart format off
    final x = zeros([2, 3]);  expect(x.shape, [2, 3]);
                              expect(x.dtype, DType.float32);
    // dart format on
  });

  test('unsqueeze', () {
    // dart format off
    final x = zeros([2, 3]);  expect(x.unsqueeze(0).shape, [1, 2, 3]);
                              expect(x.unsqueeze(1).shape, [2, 1, 3]);
                              expect(x.unsqueeze(2).shape, [2, 3, 1]);
                              expect(x.unsqueeze(-1).shape, x.unsqueeze(2).shape);
                              expect(x.unsqueeze(-2).shape, x.unsqueeze(1).shape);
    // dart format on
  });

  test('squeeze', () {
    // dart format off
    final x = zeros([2, 3]);  expect(x.unsqueeze(0).squeeze(0).shape, x.shape);
                              expect(x.unsqueeze(1).squeeze(1).shape, x.shape);
                              expect(x.unsqueeze(2).squeeze(2).shape, x.shape);
                              expect(x.unsqueeze(-1).squeeze(-1).shape, x.shape);
                              expect(x.unsqueeze(-2).squeeze(-2).shape, x.shape);
    // dart format on
  });
}