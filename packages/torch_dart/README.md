# torch_dart

通过 `py_embed` 提供公共 Tensor 接口和 Python PyTorch 后端。

- `lib/src/base.dart`：公共 API 与内部后端契约。
- `lib/src/backend/python.dart`：Python 对象包装与后端实现。
- `lib/torch_dart.dart`：公共导出，隐藏后端细节。

首次使用时导入 `torch`。运行前将安装了 PyTorch 的 Python 环境加入
`PATH`，确保 `python` 命令和对应的 Python 动态库可用。

目前提供：

- 数据创建：`tensor`、`zeros`、`ones`、`randn`、`arange`。
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
Python 引用，需要单独 `dispose()`。不同包装器可能共享底层存储。
每个包装器只释放一次，释放后不再使用。原地方法返回原包装器。
目前临时运算结果也需要显式释放，尚未提供 Tensor scope。

`tensor` 接受数字、布尔值或它们的嵌套 List；零维 Tensor 的 `toList()` 返回标量。
复数 Tensor 暂不支持 `item` / `toList` 数据读取。运算和梯度遵循 PyTorch 语义，
后端错误以 `PyException` 传播。`nn` 和优化器尚未实现。

Python 后端要求 `py_embed >= 0.5.1`，标量构造和字符串转换由底层负责 GIL 保护。
Python 初始化尚无跨 isolate 锁，首次使用需串行；测试配置设置 `concurrency: 1`。
