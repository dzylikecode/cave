import 'package:py_embed/py_embed.dart' show using, PyException;
import 'package:test/test.dart';
import 'package:torch_dart/nn.dart' as nn;
import 'package:torch_dart/torch_dart.dart';

void main() {
  test(
    'Conv2d computes parameter gradients with requested dtype and device',
    () {
      using((scope) {
        final conv = nn.Conv2d(
          1,
          1,
          3,
          bias: false,
          dtype: DType.float64,
          device: Device(DeviceType.cpu),
        );
        scope.defer(conv.dispose);
        final input = ones(
          [1, 1, 6, 6],
          dtype: DType.float64,
          requires_grad: true,
        );
        scope.defer(input.dispose);
        final output = conv([input]);
        scope.defer(output.dispose);
        expect(output.shape, [1, 1, 4, 4]);
        expect(output.dtype, DType.float64);
        expect(output.device, Device(DeviceType.cpu));
        final loss = output.sum();
        scope.defer(loss.dispose);
        loss.backward();
        final parameters = conv.parameters();
        for (final param in parameters) {
          scope.defer(param.dispose);
        }
        expect(parameters.length, 1);
        expect(parameters.single.shape, [1, 1, 3, 3]);
        final gradient = parameters.single.grad!;
        scope.defer(gradient.dispose);
        expect(gradient.toList(), [
          [
            [
              [16.0, 16.0, 16.0],
              [16.0, 16.0, 16.0],
              [16.0, 16.0, 16.0],
            ],
          ],
        ]);
      });
    },
  );

  test(
    'Conv2d forwards rectangular kernels, groups, stride and padding mode',
    () {
      using((scope) {
        final conv = nn.Conv2d(
          4,
          4,
          [3, 5],
          stride: [2, 2],
          padding: [1, 2],
          dilation: [1, 1],
          groups: 2,
          padding_mode: 'reflect',
        );
        scope.defer(conv.dispose);
        final input = ones([2, 4, 8, 10]);
        scope.defer(input.dispose);
        final output = conv([input]);
        scope.defer(output.dispose);
        expect(output.shape, [2, 4, 4, 5]);
        final parameters = conv.parameters();
        for (final param in parameters) {
          scope.defer(param.dispose);
        }
        expect(parameters.map((p) => p.shape), [
          [4, 2, 3, 5],
          [4],
        ]);
      });
    },
  );

  test('Conv2d supports string padding, dilation and backend validation', () {
    using((scope) {
      final conv = nn.Conv2d(1, 2, 3, padding: 'same', dilation: 2);
      scope.defer(conv.dispose);
      final input = zeros([1, 1, 8, 10]);
      scope.defer(input.dispose);
      final output = conv.forward([input]);
      scope.defer(output.dispose);
      expect(output.shape, [1, 2, 8, 10]);
      expect(() => nn.Conv2d(3, 4, 3, groups: 2), throwsA(isA<PyException>()));
    });
  });
}
