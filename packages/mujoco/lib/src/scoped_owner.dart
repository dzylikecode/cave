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
