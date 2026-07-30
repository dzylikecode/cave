可以先忽略实现细节，只看我们要解决的三个问题：

1. Dart 拿到 `PyObject*` 后，怎样保证它不会提前被 Python 销毁？
2. Dart 不再使用对象时，怎样正确执行 `Py_DecRef`？
3. 用户忘记 `dispose()` 时，怎样兜底，而且不能在 `Py_Finalize()` 之后释放对象？

我的完整设计是三层：

```text
Python                解释器生命周期
  └── _PythonRuntime  内部协调器，不对用户公开
        └── PyRef     单个 PyObject* 的引用生命周期
              └── PyObject / PyList / PyString...
```

用户只看见：

```text
Python
PyObject
PyString
PyList
PyDict
```

`_PythonRuntime` 和 `PyRef` 都是包内部实现。

---

## 一、先确定唯一的所有权规则

整个库只采用一条规则：

> 每一个活着的 Dart `PyObject` 包装器，都独立拥有一个 Python 引用。

比如：

```dart
final text = PyString('hello');
```

此时：

```text
Dart text ──拥有一个引用──> Python str
```

引用计数可能是：

```text
Python str refcount = 1
```

如果把它加入 Python list：

```dart
list.append(text);
```

`PyList_Append` 会让 list 获得自己的引用：

```text
Dart text ──一个引用──┐
                     ├──> Python str，refcount = 2
Python list ─一个引用─┘
```

然后：

```dart
text.dispose();
```

只是释放 Dart 的引用：

```text
Python list ─一个引用──> Python str，refcount = 1
```

对象仍然存活，不会影响 Python 使用它。

等 list 也释放这个元素后：

```text
refcount = 0
Python str 真正销毁
```

所以用户不需要思考“Python 是否还在使用它”。只需要保证：

> 每一个需要长期使用对象的持有者，都拥有自己的引用。

CPython 的 list、dict、attribute 等 API 通常会自动处理这件事。

---

## 二、`PyRef` 只负责一个 `PyObject*`

`PyRef` 是生命周期类。它不提供字符串、列表、属性等功能，只负责：

- 当前指针是否有效
- Dart 是否拥有该引用
- `INCREF`
- `DECREF`
- 防止重复释放
- Finalizer 兜底

概念代码：

```dart
final class PyRef implements Finalizable {
  Pointer<g.PyObject> _ptr;

  PyRef.owned(this._ptr);

  factory PyRef.borrowed(Pointer<g.PyObject> ptr) {
    g.Py_IncRef(ptr);
    return PyRef.owned(ptr);
  }

  Pointer<g.PyObject> get ptr {
    if (_ptr == nullptr) {
      throw StateError('Python object has been disposed');
    }
    return _ptr;
  }

  void dispose() {
    if (_ptr == nullptr) return;

    final value = _ptr;
    _ptr = nullptr;

    g.Py_DecRef(value);
  }
}
```

这只是概念版。实际版本不能直接这样使用 Finalizer，因为 `Py_DecRef` 依赖解释器和 GIL，后面会讲。

---

## 三、为什么有 `owned` 和 `borrowed` 两个入口

CPython API 返回的指针有两种主要情况。

### New reference

例如：

```c
PyUnicode_FromString(...)
PyList_New(...)
PyObject_GetAttrString(...)
PyNumber_Add(...)
```

它们返回一个新引用，也就是引用已经属于调用者。

所以 Dart 直接接管：

```dart
final ptr = g.PyUnicode_FromString(...);
final ref = PyRef.owned(ptr);
```

这里不能再 `INCREF`，否则会多出一个无法释放的引用。

### Borrowed reference

例如：

```c
PyList_GetItem(...)
PyTuple_GetItem(...)
PyDict_GetItem(...)
```

返回的引用属于容器，调用者只是暂时借用。

假设 list 中有一个字符串：

```text
Python list ──拥有引用──> Python str
Dart ptr    ---借用-----> Python str
```

如果 Dart 直接保存这个指针，之后 list 被销毁，Dart 指针就悬空了。

所以 Dart 拿到 borrowed reference 后立即执行：

```dart
Py_IncRef(ptr);
```

转换成自己的 owned reference：

```dart
final ptr = g.PyList_GetItem(list.ptr, 0);
final ref = PyRef.borrowed(ptr);
```

转换后：

```text
Python list ──一个引用──┐
                       ├──> Python str
Dart object ─一个引用───┘
```

从 `PyRef` 构造完成开始，owned 和 borrowed 就没有区别了。

它们的区别只存在于创建时：

```text
new reference      → 直接接管
borrowed reference → 先 INCREF，再接管
```

---

## 四、`PyObject` 不处理生命周期，只组合 `PyRef`

`PyObject` 负责通用 Python 对象操作：

```dart
class PyObject {
  final PyRef _ref;

  PyObject.owned(Pointer<g.PyObject> ptr)
      : _ref = PyRef.owned(ptr);

  PyObject.borrowed(Pointer<g.PyObject> ptr)
      : _ref = PyRef.borrowed(ptr);

  Pointer<g.PyObject> get ptr => _ref.ptr;

  void dispose() => _ref.dispose();

  PyObject get(String name) {
    final result = g.PyObject_GetAttrString(ptr, ...);

    // PyObject_GetAttrString 返回 new reference。
    return PyObject.owned(result);
  }
}
```

这里职责很明确：

```text
PyObject
  负责：get、set、call、运算符等 Python 操作

PyRef
  负责：INCREF、DECREF、disposed 状态、兜底释放
```

`PyObject` 不直接调用 `Py_DecRef`。

---

## 五、具体 Python 类型通过继承提供能力

```dart
class PyList extends PyObject {
  PyList.owned(super.ptr) : super.owned();

  int append(PyObject value) {
    return g.PyList_Append(ptr, value.ptr);
  }

  PyObject getItem(int index) {
    final result = g.PyList_GetItem(ptr, index);

    // GetItem 返回 borrowed reference。
    return PyObject.borrowed(result);
  }
}
```

```dart
class PyString extends PyObject {
  PyString.owned(super.ptr) : super.owned();

  factory PyString(String value) {
    final ptr = g.PyUnicode_FromString(...);

    // FromString 返回 new reference。
    return PyString.owned(ptr);
  }
}
```

因此：

- 生命周期关系用组合：`PyObject` 持有 `PyRef`
- Python 类型关系用继承：`PyList extends PyObject`

这就是“一个类只负责一件事”。

---

## 六、传给 Python 后为什么可以销毁 Dart 对象

例如：

```dart
final value = PyString('hello');
final list = PyList();

list.append(value);
value.dispose();
```

`PyList_Append` 会给 list 增加一个引用：

```text
1. PyString 创建

Dart value → str
refcount = 1


2. list.append(value)

Dart value → str ← Python list
refcount = 2


3. value.dispose()

              str ← Python list
refcount = 1
```

所以 Dart 释放自己的引用不会影响 list。

类似的 API 包括：

- `PyList_Append`
- `PyList_Insert`
- `PyDict_SetItem`
- `PyObject_SetAttrString`

它们会让 Python 容器拥有自己的引用。

---

## 七、特殊情况：steal reference

`PyList_SetItem` 和 `PyTuple_SetItem` 比较特殊，它们会偷走调用者的引用。

如果直接这样调用：

```dart
g.PyList_SetItem(list.ptr, 0, value.ptr);
```

会变成：

```text
Dart value 认为自己拥有引用
Python list 也认为这个引用属于自己

但实际上总共只有一个引用
```

将来两边都可能 `DECREF`，产生重复释放。

解决方法是传入前创建一个新引用：

```dart
final newRef = value.newReference();
g.PyList_SetItem(list.ptr, 0, newRef);
```

`newReference()` 的实现：

```dart
Pointer<g.PyObject> newReference() {
  g.Py_IncRef(ptr);
  return ptr;
}
```

过程是：

```text
开始：
Dart value → str
refcount = 1

newReference：
Dart value → str
新引用    → str
refcount = 2

PyList_SetItem 偷走新引用：
Dart value  → str
Python list → str
refcount = 2
```

之后 Dart 和 list 都能独立释放。

这个差异应该由 `PyList.setItem()` 内部处理，不应该让用户处理。

用户仍然只写：

```dart
list.setItem(0, value);
```

---

## 八、为什么不能让 Finalizer 直接 `Py_DecRef`

我们希望支持：

```dart
void foo() {
  final value = PyString('hello');

  // 忘记 value.dispose()
}
```

Dart GC 最终会发现 `value` 不再使用，然后触发 Finalizer。

最简单的写法看起来是：

```dart
static final Finalizer<Pointer<g.PyObject>> finalizer =
    Finalizer(g.Py_DecRef);
```

但这样不安全，因为 Finalizer 执行时：

- 不确定 Python 是否仍然初始化
- 不确定是否持有 GIL
- 可能已经调用了 `Py_Finalize`
- `Py_DecRef` 可能触发 Python 对象的 `__del__`
- `__del__` 可能继续执行 Python 代码

所以 Finalizer 不能随时直接调用 `Py_DecRef`。

---

## 九、内部 `_PythonRuntime` 的作用

因此需要一个内部协调器 `_PythonRuntime`。

它负责：

- Python 是否已经初始化
- Python 是否正在关闭
- 当前还有哪些 `PyRef`
- 哪些引用是 Finalizer 发现的待释放对象
- 在 `Py_Finalize()` 前释放全部引用
- 未来统一处理 GIL

```text
_PythonRuntime
  ├── liveReferences：所有仍存活的 PyRef 状态
  └── pendingReleases：Finalizer 请求释放的状态
```

它不需要导出，也不需要用户传入。

当前只有主解释器，所以可以使用包内部单例：

```dart
final class _PythonRuntime {
  _PythonRuntime._();

  static final instance = _PythonRuntime._();
}
```

用户不会看到它。

---

## 十、Finalizer 只负责“提交释放请求”

当 `PyRef` 被 Dart GC 回收时，Finalizer 不直接调用 Python，而是告诉 runtime：

```text
“这个 PyObject* 已经没有 Dart 包装器使用了，
请在安全时机释放它。”
```

例如：

```dart
static final Finalizer<_PyRefState> _finalizer = Finalizer(
  (state) {
    _PythonRuntime.instance.releaseLater(state);
  },
);
```

`releaseLater()` 只是放进队列：

```dart
void releaseLater(_PyRefState state) {
  if (state.isDisposed || state.queued) return;

  state.queued = true;
  _pendingReleases.add(state);
}
```

这里没有调用任何 Python C API，所以即使 Finalizer 时机不可控，也不会立即进入 Python。

---

## 十一、什么时候真正 `DECREF`

有三个安全释放时机。

### 用户显式调用 `dispose()`

```dart
value.dispose();
```

此时立即交给 runtime：

```dart
void dispose() {
  _finalizer.detach(_detachToken);
  _PythonRuntime.instance.releaseNow(_state);
}
```

runtime 在解释器有效、持有 GIL的情况下执行：

```dart
Py_DecRef(ptr);
```

这是主要释放路径。

### 下一次进入 Python API

Finalizer 放进队列后，下次调用 Python：

```dart
list.append(value);
python.runSimpleString(...);
object.get(...);
```

runtime 会先清空待释放队列：

```dart
T execute<T>(T Function() operation) {
  _ensurePythonIsRunning();
  _acquireGil();

  try {
    _drainPendingReleases();
    return operation();
  } finally {
    _releaseGil();
  }
}
```

所以 GC 发现的对象会在安全进入 Python 时释放。

### `Python.dispose()`

这是最后的强制兜底。

```dart
python.dispose();
```

内部顺序必须是：

```text
1. 禁止创建和使用新的 PyObject
2. 清空 Finalizer 待释放队列
3. 释放所有仍登记的 PyRef
4. 确认没有剩余 Python 引用
5. 调用 Py_Finalize()
```

也就是：

```dart
void dispose() {
  _closing = true;

  _withGil(() {
    _drainPendingReleases();
    _releaseAllLiveReferences();
  });

  g.Py_Finalize();

  _initialized = false;
}
```

因此，即使用户一个 `dispose()` 都没写：

```dart
final python = Python();
final a = PyString('a');
final b = PyList();
final c = PyDict();

python.dispose();
```

runtime 也会在 `Py_Finalize()` 前释放 `a/b/c`。

---

## 十二、为什么 runtime 要登记所有引用

假设对象还没被 GC：

```dart
final value = PyString('hello');
python.dispose();
```

因为 `value` 仍然是活跃变量，所以 Finalizer 根本不会运行。

如果 runtime 只依赖 Finalizer，就无法知道还有一个 Python 对象没释放。

因此，每个 `PyRef` 创建时都要登记：

```dart
_runtime.register(state);
```

显式释放时注销：

```dart
_runtime.unregister(state);
```

runtime 关闭时遍历剩余状态：

```dart
for (final state in _liveReferences) {
  Py_DecRef(state.ptr);
}
```

这使得 `Python.dispose()` 成为真正可靠的最终兜底。

注意 runtime 登记的是 `_PyRefState`，不是 `PyRef` 对象本身。

如果 runtime 直接保存 `PyRef`：

```dart
Set<PyRef> references;
```

它会形成强引用，导致 `PyRef` 永远无法被 GC，Finalizer 也永远不会触发。

因此需要拆分：

```text
PyRef                 Dart 包装器，可以被 GC
  └── _PyRefState     只保存指针和释放状态

_PythonRuntime
  └── _PyRefState     不反向引用 PyRef
```

---

## 十三、用户最终看到的 API

用户完全不需要接触 `_PythonRuntime` 或 `PyRef`：

```dart
final python = Python.venv(pythonExe);

try {
  final module = PyModule('example');
  final value = PyString('hello');
  final args = PyTuple.fromList([value]);

  final result = module.get('run').call(args);

  print(result);

  result.dispose();
  args.dispose();
  value.dispose();
  module.dispose();
} finally {
  python.dispose();
}
```

也允许依赖兜底：

```dart
final python = Python.venv(pythonExe);

final module = PyModule('example');
final result = module.get('run').call(
  PyTuple.fromList([
    PyString('hello'),
  ]),
);

print(result);

python.dispose(); // 释放所有遗漏对象，然后关闭解释器
```

不过仍然推荐显式 `dispose()`，因为 Finalizer 的释放时间不确定。兜底保证安全，显式释放保证资源及时归还。

---

## 十四、各个类最终只做什么

### `Python`

公开的解释器门面：

```text
init
initFromConfig
runSimpleString
dispose
```

### `_PythonRuntime`

包内部协调器：

```text
解释器状态
GIL
活跃引用登记
Finalizer 释放队列
关闭顺序
```

### `PyRef`

单个指针的生命周期：

```text
owned / borrowed
INCREF / DECREF
是否已释放
显式 dispose
Finalizer attach/detach
```

### `PyObject`

Python 通用操作：

```text
get
set
call
运算符
```

内部组合一个 `PyRef`。

### `PyList`、`PyDict`、`PyString`

具体类型能力：

```text
PyList：append、getItem、setItem
PyDict：keys、values、setItem
PyString：Dart String 转换
```

它们不负责实现引用生命周期。

---

一句话总结整个设计：

> Dart 中每个 `PyObject` 都通过内部 `PyRef` 独立持有一个 Python 引用；显式 `dispose()` 立即归还引用，Dart Finalizer 只提交延迟释放请求，内部 runtime 在安全时机统一 `DECREF`，并保证所有对象在 `Py_Finalize()` 之前被释放。

这样用户的心智模型只剩下：

```text
拿到 PyObject → Dart 拥有它
传给 Python → Python 根据 API 获得自己的引用
dispose PyObject → 只释放 Dart 自己的引用
忘记 dispose → runtime 最终兜底
```