import 'package:py_embed/py_embed.dart' show PyException;
import 'package:test/test.dart';
import 'package:torch_dart/torch_dart.dart';

void main() {
  late List<Tensor> owned;
  Tensor own(Tensor value) {
    owned.add(value);
    return value;
  }

  setUp(() => owned = []);
  tearDown(() {
    for (final value in owned.reversed) {
      value.dispose();
    }
  });

  test('data creation, scalar readback and shape-preserving lists', () {
    final x = own(
      tensor([
        [1, 2],
        [3, 4],
      ]),
    );
    expect(x.dtype, DType.int64);
    expect(x.ndim, 2);
    expect(x.numel, 4);
    expect(x.toList(), [
      [1, 2],
      [3, 4],
    ]);
    expect(own(tensor(true)).item(), true);
    expect(own(tensor(2.5)).toList(), 2.5);
    expect(own(zeros([2, 0])).toList(), [[], []]);
    expect(own(ones([2])).toList(), [1.0, 1.0]);
    final samples = own(randn([2, 3], requires_grad: true));
    expect(samples.shape, [2, 3]);
    expect(samples.requires_grad, isTrue);
  });

  test(
    'manual_seed reproduces random sequences and accepts negative seeds',
    () {
      for (final seed in [42, 0, -1, -9223372036854775808]) {
        manual_seed(seed);
        final first = own(randn([2, 3])).toList();
        final second = own(randn([2, 3])).toList();
        expect(second, isNot(equals(first)));

        manual_seed(seed);
        expect(own(randn([2, 3])).toList(), first);
        expect(own(randn([2, 3])).toList(), second);
      }
      manual_seed(43);
      final first = own(randn([8])).toList();
      manual_seed(44);
      expect(own(randn([8])).toList(), isNot(equals(first)));
    },
  );

  test('broadcast arithmetic, activations and reductions', () {
    final x = own(
      tensor([
        [-1.0, 2.0],
        [3.0, 4.0],
      ]),
    );
    final bias = own(tensor([1.0, 2.0]));
    expect(own(x + bias).toList(), [
      [0.0, 4.0],
      [4.0, 6.0],
    ]);
    expect(own(x - 1).toList(), [
      [-2.0, 1.0],
      [2.0, 3.0],
    ]);
    expect(own(x * 2).toList(), [
      [-2.0, 4.0],
      [6.0, 8.0],
    ]);
    expect(own(x / 2).toList(), [
      [-0.5, 1.0],
      [1.5, 2.0],
    ]);
    expect(own(-x).toList(), [
      [1.0, -2.0],
      [-3.0, -4.0],
    ]);
    expect(own(x.relu()).toList(), [
      [0.0, 2.0],
      [3.0, 4.0],
    ]);
    expect(own(x.sum()).item(), 8.0);
    expect(own(x.mean()).item(), 2.0);
    expect(own(x.sum(keepdim: true)).toList(), [
      [8.0],
    ]);
    expect(own(x.mean(keepdim: true)).toList(), [
      [2.0],
    ]);
    final scalar = own(tensor(3.0));
    expect(own(scalar.mean()).item(), 3.0);
    expect(own(scalar.sum(keepdim: true)).shape, isEmpty);
    expect(own(scalar.mean(keepdim: true)).item(), 3.0);
    expect(own(x.sum(dim: 0, keepdim: true)).toList(), [
      [2.0, 6.0],
    ]);
    expect(own(x.mean(dim: 1)).toList(), [0.5, 3.5]);
    final zero = own(tensor(0.0));
    expect(own(zero.sigmoid()).item(), 0.5);
    expect(own(zero.tanh()).item(), 0.0);
    expect(own(zero.exp()).item(), 1.0);
    expect(own(own(tensor(1.0)).log()).item(), 0.0);
    expect(() => x + 'invalid', throwsA(isA<PyException>()));
  });

  test('linear computation and mean squared error backward', () {
    final input = own(
      tensor([
        [1.0, 2.0],
        [3.0, 4.0],
      ]),
    );
    final weight = own(
      tensor([
        [1.0, 1.0],
      ], requires_grad: true),
    );
    final bias = own(zeros([1], requires_grad: true));
    expect(weight.is_leaf, isTrue);
    expect(weight.grad, isNull);
    final product = own(input.matmul(own(weight.transpose(0, 1))));
    final prediction = own(product + bias);
    expect(prediction.toList(), [
      [3.0],
      [7.0],
    ]);
    final loss = own(own(prediction.pow(2)).mean());
    expect(loss.item(), 29.0);
    loss.backward();
    expect(own(weight.grad!).toList(), [
      [24.0, 34.0],
    ]);
    expect(own(bias.grad!).toList(), [10.0]);
    weight.zero_grad(set_to_none: false);
    expect(own(weight.grad!).toList(), [
      [0.0, 0.0],
    ]);
    bias.zero_grad();
    expect(bias.grad, isNull);
  });

  test(
    'parameter update under no_grad changes leaf values and preserves identity',
    () {
      final weight = own(tensor([2.0, 3.0], requires_grad: true));
      final loss = own(own(weight.pow(2)).sum());
      loss.backward();
      final gradient = own(weight.grad!);
      expect(no_grad(() => weight.add_(gradient, alpha: -0.25)), same(weight));
      expect(weight.toList(), [1.0, 1.5]);
      expect(weight.is_leaf, isTrue);
      expect(weight.requires_grad, isTrue);
      expect(no_grad(() => weight.mul_(2)), same(weight));
      expect(weight.toList(), [2.0, 3.0]);
      final source = own(tensor([4.0, 5.0]));
      expect(no_grad(() => weight.copy_(source)), same(weight));
      expect(weight.toList(), [4.0, 5.0]);
      weight.zero_grad();
    },
  );

  test('explicit backward seed, gradient accumulation and retained graph', () {
    final x = own(tensor([2.0, 3.0], requires_grad: true));
    final y = own(x.pow(2));
    y.retain_grad();
    final seed = own(tensor([1.0, 2.0]));
    y.backward(gradient: seed, retain_graph: true);
    expect(own(x.grad!).toList(), [4.0, 12.0]);
    expect(own(y.grad!).toList(), [1.0, 2.0]);
    y.backward(gradient: seed);
    expect(own(x.grad!).toList(), [8.0, 24.0]);
  });

  test('higher order gradients', () {
    final x = own(tensor(2.0, requires_grad: true));
    final y = own(x.pow(3));
    y.backward(create_graph: true);
    final first = own(x.grad!);
    expect(first.item(), 12.0);
    x.zero_grad(); // Break the reference cycle created by create_graph.
    first.backward();
    expect(own(x.grad!).item(), 12.0);
    x.zero_grad();
  });

  test('no_grad restores recording after success and exception', () {
    final x = own(tensor(2.0, requires_grad: true));
    expect(no_grad(() => own(x * 2)).requires_grad, isFalse);
    expect(
      no_grad(() => own(ones([1], requires_grad: true))).requires_grad,
      isTrue,
    );
    expect(
      () => no_grad<void>(() => throw StateError('test')),
      throwsStateError,
    );
    expect(own(x * 2).requires_grad, isTrue);
    expect(own(x.detach()).requires_grad, isFalse);
    final leaf = own(tensor(3.0));
    leaf.requires_grad = true;
    expect(leaf.requires_grad, isTrue);
    leaf.requires_grad = false;
    expect(leaf.requires_grad, isFalse);
    leaf.requires_grad = true;
    final nonLeaf = own(leaf * 2);
    expect(nonLeaf.requires_grad, isTrue);
    expect(() => nonLeaf.requires_grad = false, throwsA(isA<PyException>()));
  });

  test('conversion, clone and no-op wrappers have independent lifetimes', () {
    final x = own(
      tensor([
        [1.0, 2.0],
        [3.0, 4.0],
      ]),
    );
    final alias = own(x.to());
    final copy = own(x.clone());
    final converted = own(
      x.to(dtype: DType.float64, device: Device(DeviceType.cpu)),
    );
    expect(converted.dtype, DType.float64);
    expect(converted.device, Device(DeviceType.cpu));
    final transposed = own(x.transpose(0, 1));
    expect(own(transposed.contiguous()).toList(), [
      [1.0, 3.0],
      [2.0, 4.0],
    ]);
    owned.remove(x);
    x.dispose();
    expect(alias.toList(), [
      [1.0, 2.0],
      [3.0, 4.0],
    ]);
    expect(copy.toList(), alias.toList());
  });

  test('invalid creation and unsupported complex reads', () {
    expect(() => zeros([-1]), throwsA(isA<PyException>()));
    expect(() => ones([-1]), throwsA(isA<PyException>()));
    expect(() => randn([-1]), throwsA(isA<PyException>()));
    expect(() => tensor(['invalid']), throwsArgumentError);
    final cyclic = <Object>[];
    cyclic.add(cyclic);
    expect(() => tensor(cyclic), throwsArgumentError);
    final complex = own(zeros([], dtype: DType.complex64));
    expect(complex.item, throwsUnsupportedError);
    expect(complex.toList, throwsUnsupportedError);
  });
}
