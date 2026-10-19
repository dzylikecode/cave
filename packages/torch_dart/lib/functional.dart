/// Additional tensor operations used by learning algorithms.
///
/// Operations currently use the Python backend. Returned tensors are owned by
/// the caller. [tensorScope] can release all intermediate Python references.
library;

import 'package:py_embed/py_embed.dart';

import 'src/base.dart';
import 'src/backend/python.dart' show TensorPython;

PyObject _handle(Tensor value) => (value as PyObjectWrapper).handle;

/// Releases temporary tensor references created synchronously in [action].
/// Use [keepTensor] for each tensor escaping to the parent scope.
T tensorScope<T>(T Function() action) => ResourceScope.scope(action);

/// Removes a tensor from automatic scopes; its owner must dispose it explicitly.
Tensor ownTensor(Tensor value) {
  _handle(value).detachFromScope();
  return value;
}

/// Moves an owned tensor reference from the current scope to its parent.
Tensor keepTensor(Tensor value) {
  _handle(value).detachToParentScope();
  return value;
}

Tensor _torch(
  String name,
  List<Object?> args, [
  Map<String, Object?>? kwargs,
]) => ResourceScope.scope(
  () => TensorPython(
    PyModule('torch')
        .getAttr(name)
        .forward(args, kwargs: kwargs)
        .detachToParentScope(),
  ),
);

Tensor rand(List<int> shape, {Device? device}) =>
    _torch('rand', [shape], {if (device != null) 'device': '$device'});
Tensor minimum(Tensor a, Tensor b) => _torch('minimum', [a, b]);
Tensor where(Tensor condition, Tensor a, Tensor b) =>
    _torch('where', [condition, a, b]);

Tensor stack(List<Tensor> tensors, {int dim = 0}) =>
    _torch('stack', [tensors], {'dim': dim});
Tensor cat(List<Tensor> tensors, {int dim = 0}) =>
    _torch('cat', [tensors], {'dim': dim});
Tensor maximum(Tensor a, Tensor b) => _torch('maximum', [a, b]);
Tensor normal(Tensor mean, Tensor std) => _torch('normal', [mean, std]);
Tensor randperm(int n, {Device? device}) =>
    _torch('randperm', [n], {if (device != null) 'device': '$device'});

extension TensorOperations on Tensor {
  Tensor _method(
    String name,
    List<Object?> args, [
    Map<String, Object?>? kwargs,
  ]) => ResourceScope.scope(
    () => TensorPython(
      _handle(this)
          .getAttr(name)
          .forward(args, kwargs: kwargs)
          .detachToParentScope(),
    ),
  );
  Tensor zero_() {
    _method('zero_', []).dispose();
    return this;
  }
  Tensor abs() => _method('abs', []);
  Tensor sqrt() => _method('sqrt', []);
  Tensor gt(Object value) => _method('gt', [value]);
  Tensor ge(Object value) => _method('ge', [value]);
  Tensor lt(Object value) => _method('lt', [value]);
  Tensor eq(Object value) => _method('eq', [value]);
  Tensor remainder(int divisor) => _method('remainder', [divisor]);
  Tensor logicalOr(Tensor other) => _method('logical_or', [other]);
  Tensor logicalAnd(Tensor other) => _method('logical_and', [other]);
  Tensor logicalNot() => _method('logical_not', []);
  Tensor any({int? dim}) => _method('any', [], {'dim': ?dim});
  Tensor isfinite() => _method('isfinite', []);
  Tensor nonzero() => _method('nonzero', []);
  Tensor indexCopy_(int dim, Tensor indices, Tensor source) {
    _method('index_copy_', [dim, indices, source]).dispose();
    return this;
  }

  Tensor indexFill_(int dim, Tensor indices, num value) {
    _method('index_fill_', [dim, indices, value]).dispose();
    return this;
  }

  Tensor select(int dim, int index) => _method('select', [dim, index]);
  Tensor narrow(int dim, int start, int length) =>
      _method('narrow', [dim, start, length]);
  Tensor indexSelect(int dim, Tensor indices) =>
      _method('index_select', [dim, indices]);
  Tensor clamp(num min, num max) => _method('clamp', [min, max]);
  Tensor std({bool unbiased = true}) =>
      _method('std', [], {'unbiased': unbiased});
  Tensor elu() => _torchFunctional('elu');
  Tensor selu() => _torchFunctional('selu');
  Tensor leakyRelu() => _torchFunctional('leaky_relu');
  Tensor _torchFunctional(String name) => ResourceScope.scope(
    () => TensorPython(
      PyModule('torch.nn.functional')
          .getAttr(name)
          .forward([this])
          .detachToParentScope(),
    ),
  );
}

/// Clips gradients in place and returns the total norm before clipping.
double clipGradNorm(List<Tensor> parameters, double maxNorm) =>
    ResourceScope.scope(
      () =>
          PyModule('torch.nn.utils')
              .getAttr('clip_grad_norm_')
              .forward([parameters, maxNorm])
              .getAttr('item')
              .call0()
              .asDouble(),
    );
