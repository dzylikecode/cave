# torch_dart

参考 MuJoCo 的 API 组织方式构建的 PyTorch Dart 绑定，目前仅包含最小骨架。

- `lib/src/base.dart`：公共入口 `Torch` 和内部后端契约 `BaseApi`。
- `lib/src/backend/python.dart`：通过 `py_embed` 实现的 `PythonApi`。
- `lib/torch_dart.dart`：导出公共接口，隐藏后端实现细节。

当前使用 Python 后端，首次访问时才导入 `torch`。运行示例需要
`py_embed` 使用的 Python 环境已安装 PyTorch。

```dart
import 'package:torch_dart/torch_dart.dart';

void main() {
  print(Torch.version);
}
```

Tensor、创建函数、运算、模型加载和生命周期接口待讨论后逐步加入。
