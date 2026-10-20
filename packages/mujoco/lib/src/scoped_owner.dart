import 'base.dart';

import 'package:resource_scope/resource_scope.dart';

mixin ScopedOwner implements ScopedResource {
  bool _isDisposed = false;

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    ResourceScope.untrack(this);
  }

  @override
  ScopedResource detachFromScope() {
    ResourceScope.untrack(this);
    return this;
  }

  @override
  ScopedResource detachToParentScope() {
    ResourceScope.promoteToParent(this);
    return this;
  }
}

/// A view that rejects access after its owner is disposed.
class GuardedDoubleListView(
  final MjDoubleListView source,
  final void Function() checkAlive,
) implements MjDoubleListView {
  @override
  int get length {
    checkAlive();
    return source.length;
  }

  @override
  double operator [](int index) {
    checkAlive();
    RangeError.checkValidIndex(index, this, 'index', source.length);
    return source[index];
  }

  @override
  void operator []=(int index, double value) {
    checkAlive();
    RangeError.checkValidIndex(index, this, 'index', source.length);
    source[index] = value;
  }

  @override
  List<double> toList() {
    checkAlive();
    return source.toList();
  }
}
