# py_embed

ffi for [python c api](https://devguide.python.org/developer-workflow/c-api/index.html)

用户心智认知最低作为最高约束

```dart
void main() {
  final value = PyString('hello');
  print(value.value);
}
```

> [!NOTE]
>
> 假设当前有一个 python 虚拟环境

- 不需要创建python
- 不需要显示释放什么

所有权模型也是化简的：创建 Dart `PyObject` 就可以直接使用；每个 Dart 对象独立持有一个 Python 引用。

同时保持灵活性，可以显示指定 Python 环境

```dart
Future<void> main() async {
  Python.configure(
    executable: await getPyExecutableFromShell(),
  );

  final value = PyString('hello');
  print(value.value);
}
```

确定性释放资源

```dart
void main() {
  final value = PyString('hello');

  try {
    print(value.value);
  } finally {
    value.dispose();
  }
}
```

明确地关闭 Python 解释器

```dart
void main() {
  final value = PyString('hello');
  print(value.value);

  Python.shutdown();
}
```

因而：

1. 第一个 Python API 自动初始化默认解释器。
2. 用户不需要创建或传递 runtime。
3. 特殊配置必须在第一次 Python API 前通过 `Python.configure()` 提供。
4. 每个 Dart `PyObject` 独立拥有一个 Python引用。
5. borrowed reference 进入 Dart 后立即提升为 owned reference。
6. steal reference 的差异由具体类型 API 内部隐藏。
7. `dispose()` 幂等，并用于及时释放。
8. Finalizer 只排队，不直接调用 Python。
9. `Python.shutdown()` 是可选的确定性关闭能力。
10. 未显式 shutdown 时，解释器存活到进程退出。



## command

```bash
dart run py_embed:create
```

## python bridge

对于这个[need_home](example/need_home.cpp)需要指定 python 的 home 才能运行

eg. windows powershell

```bash
$env:PYTHONHOME="$env:USERPROFILE\AppData\Local\.xmake\packages\p\python\3.8.10\5740ece21ecb4ee3a72178ec965adbef"
xmake run need_home
```

> 要这样才能运行，要不然就是复制exe到 `$env:USERPROFILE\AppData\Local\.xmake\packages\p\python\3.8.10\5740ece21ecb4ee3a72178ec965adbef` 下面，或者 `$env:USERPROFILE\AppData\Roaming\uv\python\cpython-3.8-windows-x86_64-none`


然而这无疑是麻烦的，不如获取当前环境的 python home，在程序中指定默认 home，再考虑虚拟环境来测试

采用 uv 来创建虚拟环境来测试

```bash
uv venv --python 3.8.10 --seed
```

固定在本地目录:

```bash
uv python pin 3.8.10
uv venv --seed
```


进入虚拟环境后

- 可以通过python来获取python的home目录

    ```bash
    python -c "import sys; print(sys.base_prefix)"
    ```

-  获取虚拟环境

    ```bash
    python -c "import sys; print(sys.prefix)"
    ```

进入虚拟环境后可以用

```bash
dart run example/main.dart
```

在虚拟环境中打开 code，也可以直接运行程序

> setup.py 里的 name 是 distribution name，主要给 pip 和包管理系统使用；它不决定 Python 代码中的 import 名称

## python 的所有权问题

考虑闭包的典型情况，原来的调用丢失了，部分结果传递出来了，需要避免指针悬空。所以，所有权的问题是需要考虑的

为减少心智负担，所有权的规则是：
- 拿到 PyObject → Dart 拥有它


## TODO

- [x] [linux](https://github.com/dart-lang/native/issues/3524)
- [ ] code generator
- [ ] 可以针对不同的python版本进行适应，做到能够跨版本运行，基本思路就是导出多个版本的c api 根据当前版本进行绑定
     - 写一个 tool 拉取不同分支的 include
