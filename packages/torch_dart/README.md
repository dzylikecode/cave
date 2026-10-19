# torch_dart

通过 `py_embed` 提供公共 Tensor 接口和 Python PyTorch 后端。

- `lib/src/base.dart`：公共 API 与内部后端契约。
- `lib/src/backend/python.dart`：Python 对象包装与后端实现。
- `lib/torch_dart.dart`：公共导出，隐藏后端细节。

首次使用时导入 `torch`。运行前将安装了 PyTorch 的 Python 环境加入
`PATH`，确保 `python` 命令和对应的 Python 动态库可用。

目前提供：

- 数据创建：`tensor`、`zeros`、`ones`、`randn`、`arange`。
- 随机数种子：`manual_seed(int seed)`，设置所有设备的 PyTorch 随机数种子。
- 形状：`reshape`、`view`、`unsqueeze`、`squeeze`、`transpose`、`contiguous`。
- 运算：Tensor/数字的 `+ - * /`、取负、`matmul`、`pow`、`sum`、`mean`。
- 激活与数学函数：`relu`、`sigmoid`、`tanh`、`exp`、`log`。
- 梯度：`requires_grad`（getter/setter）、`is_leaf`、`grad`、`retain_grad`、
  `backward`、`zero_grad`、同步 `no_grad` 和 `inference_mode`。
- 参数更新：原地 `add_`、`mul_`、`copy_`，更新需要梯度的叶子 Tensor 时使用 `no_grad`。
- 数据读取与转换：`item`、保留形状的 `toList`、`to(device: ..., dtype: ...)`。
- TorchScript：`jit.load`，单 Tensor 输出模型的调用。

完整的梯度计算、参数更新与释放示例见 `example/tensor_autograd.dart`：

```sh
dart run example/tensor_autograd.dart
dart test
dart analyze
```

每个返回的 Tensor 包装器（包括 view、`grad` 和无转换的 `to()`）均拥有独立
Python 引用，不同包装器可能共享底层存储。Python 后端使用 `ResourceScope`
自动管理作用域内创建的引用和 Module 回调资源；作用域之外仍需显式 `dispose()`。
原地方法返回原包装器，释放后不再使用。

```dart
import 'package:py_embed/py_embed.dart' show ResourceScope;
import 'package:torch_dart/torch_dart.dart' as torch;

ResourceScope.scope(() {
  final x = torch.ones([2, 3]);
  final y = x.relu();
  print(y.toList());
}); // 自动释放 x、y 及中间 Python 引用
```

从内部作用域返回 Python 对象时，使用 `ResourceScope.returning`，或将其
`handle.detachToParentScope()` 移交给外层。`ResourceScope.unmanaged`
只关闭自动释放，不关闭分配追踪。

`tensor` 接受数字、布尔值或它们的嵌套 List；零维 Tensor 的 `toList()` 返回标量。
复数 Tensor 暂不支持 `item` / `toList` 数据读取。运算和梯度遵循 PyTorch 语义，
后端错误以 `PyException` 传播。`nn` 已支持自定义 Module 和 Linear。

Python 后端要求 `py_embed >= 0.9.0`，标量构造和字符串转换由底层负责 GIL 保护。
Python 初始化尚无跨 isolate 锁，首次使用需串行；测试配置设置 `concurrency: 1`。

## SGD

调用 `torch.manual_seed(42)` 后再使用 `torch.randn(...)`；在相同环境中重设
相同种子可以复现随机序列。该函数返回 `void`，不暴露 PyTorch 的 Generator。

```dart
import 'package:torch_dart/optim.dart' as optim;
import 'package:torch_dart/torch_dart.dart' as torch;

final weight = torch.tensor(2.0, requires_grad: true);
final optimizer = optim.SGD([weight], lr: 0.1, momentum: 0.9);
optimizer.zero_grad();
final loss = weight.pow(2);
loss.backward();
optimizer.step();
loss.dispose();
optimizer.dispose();
weight.dispose();
```

`SGD` 直接包装 Python 优化器，支持 `lr`、`momentum`、`dampening`、
`weight_decay`、`nesterov`。参数列表和选项由 PyTorch 校验。
优化器持有自己的参数引用；调用方仍需释放自己的 Tensor 包装器。
完整训练与释放示例：`dart run example/sgd.dart`。

## Adam

使用同一组 `zero_grad()`、`step()`、`dispose()` 接口：

```dart
final optimizer = optim.Adam([weight], lr: 0.001, betas: [0.9, 0.999]);
```

直接转发 `lr`、`betas`、`eps`、`weight_decay`、`amsgrad` 到 PyTorch。

## Module

公共接口统一在 `src/base.dart`，通过 `package:torch_dart/nn.dart` 导入。
继承 `Module`，覆盖 `forward(List<Tensor> inputs, {Map<String, Tensor> kwargs = const {}})`，
用 `register_module(name, child)` 注册 Dart 保存的层。回调不需要 Python `self`。
调用 `model(inputs, kwargs: ...)` 会走 Python Module 调用流程。

第一版支持 Tensor 位置参数、Tensor 命名参数和单 Tensor 输出。
forward 的输入包装器仅在回调中借用，不应释放或保存；返回新输出即转移其所有权，
也可以原样返回输入。中间 Tensor 仍需显式释放。

`parameters()` 的每个返回包装器均需单独释放。父模型释放后再释放注册的子层，
避免 Python 仍引用子模型的 Dart 回调。示例：`dart run example/module.dart`。

## Conv2d

```dart
final conv = nn.Conv2d(1, 20, 5);
final output = conv([input]);
```

参数命名沿用 PyTorch。`kernel_size`、`stride`、`dilation` 接受整数或长度为 2
的整数 List；`padding` 还接受 `'same'` / `'valid'`。支持 `groups`、`bias`、
`padding_mode`、`device`、`dtype`。所有选项直接转发，由 PyTorch 校验。
层、输出及 `parameters()` 返回的 Tensor 包装器需按现有规则释放。

## Export to .pt

```dart
model.save_pt('model.pt', inputs: [exampleInput]);
final loaded = torch.jit.load('model.pt');
```

`save_pt` first captures an FX GraphModule, then uses TorchScript tracing to save
an inference model that does not depend on Dart callbacks. The first version
supports one positional Tensor input and one Tensor output, with no keyword
inputs. Export runs in evaluation mode and restores the original forward methods
and each layer's training flag even if export fails. The model must be FX
traceable; reading Tensor values to drive Dart control flow is not supported.
Trace with representative inputs and validate the loaded model on your intended
input shapes. Newer PyTorch versions emit a TorchScript deprecation warning.

`example/export_conv2d.dart` demonstrates the public API and verifies the saved
model in a separate Python process on several input shapes.

## Models defined by Python source

```dart
final model = nn.Module.fromSource(source, name: 'my_model');
torch.save(model, 'model.pt');
```

`Module.fromSource` constructs a Python class (default `class_name: 'Model'`).
`args` and `kwargs` are passed to its constructor. The module `name` is optional for ordinary execution and graph export. Supply
a stable `name` for whole-model pickle saving so Python can locate the class.

`torch.save` saves the Python object without example inputs. To load it, first
recreate the same named module from the source, then use Python
`torch.load(path, weights_only=False)` (omit `weights_only` on older versions
without that option). This file cannot be loaded with `jit.load`.

`save_pt` remains the separate standalone graph export path with example inputs.
See `example/source_model.dart` for both saving methods.

## Training utilities

`package:torch_dart/functional.dart` adds `stack`, `cat`, `maximum`, `normal`,
`randperm`, indexing (`select`, `narrow`, `indexSelect`), `clamp`, `std`,
ELU/SELU/LeakyReLU and `clipGradNorm`. These currently use the Python backend.
`tensorScope` releases intermediate references; return `keepTensor(result)` to
promote an output, or use `ownTensor` for persistent state that you explicitly dispose.
Scopes are synchronous for tensor operations and should not cross awaits.

`Module.registerParameter` returns an owned wrapper for the registered parameter;
`Module.to(Device)` moves parameters and buffers. Obtain parameter wrappers and
construct optimizers after moving the model to its target device.
`Optimizer.learningRate` reads/updates parameter-group learning rates without
resetting accumulated optimizer state (the getter reads the first group).

`Module.saveCheckpoint(path, optimizer: optimizer, iteration: n)` saves state
under `model_state_dict`, `optimizer_state_dict` and `iter`.
`loadCheckpoint(path, optimizer: optimizer, device: device)` restores state and
returns the saved iteration. Pass no optimizer to load weights only.

`Module.fromModule(source)` lets a typed Dart wrapper adopt a `Module.fromSource`
backend without installing a Dart forward callback. Ownership transfers; do not
dispose the original source wrapper separately. `callMethod` calls Python methods
with one Tensor result; `invokeMethod` discards the result for operations such as
reset. Both accept positional arguments and keyword arguments.

`functional.dart` also includes uniform `rand`, `minimum`, `where`, boolean
comparisons/reductions, `nonzero`, indexed copy/fill and `zero_` for vector tasks.
`ScriptModule.forwardWithState(input, states)` invokes a TorchScript model taking
`(input, tuple(states))` and returning `(output, tuple(nextStates))`, such as the
official ANYdrive actuator. The caller owns the returned output/state wrappers.
