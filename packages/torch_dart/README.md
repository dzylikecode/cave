# torch_dart

A small Dart API for [PyTorch](https://pytorch.org/). The first backend uses
`py_embed` and the official Python `torch` package. Public APIs do not expose
Python objects, so a LibTorch or other native backend can be added later.

## Setup

Create and activate a Python environment, then install PyTorch:

```bash
uv venv --seed
pip install torch
```

To select a particular Python executable, call `Python.configure` from
`package:py_embed/py_embed.dart` before the first torch operation.

## Usage

```dart
import 'package:py_embed/py_embed.dart';
import 'package:torch_dart/torch.dart';

void main() {
  final a = tensor([
    [1.0, 2.0],
    [3.0, 4.0],
  ]);
  final b = ones([2, 2]);
  final result = (a + b).matmul(b);

  try {
    print(result.shape);
    print(result.toList());
  } finally {
    result.dispose();
    b.dispose();
    a.dispose();
    Python.shutdown();
  }
}
```

The MVP includes tensor creation, shape/dtype/device metadata, element-wise
arithmetic, matrix multiplication, reshape, transpose, reductions, ReLU,
conversion to Dart lists, and deterministic random seeds.

Inference mode and TorchScript modules use a namespaced API:

```dart
final module = torch.jit.load('model.pt', mapLocation: 'cpu')..eval();
final input = randn([1, 3, 224, 224]);
final output = torch.inferenceMode(() => module(input));

try {
  print(output.shape);
} finally {
  output.dispose();
  input.dispose();
  module.dispose();
  Python.shutdown();
}
```

Each operation creates a new tensor. Dispose tensors explicitly when they are
no longer needed. Call `Python.shutdown()` once at application shutdown, after
disposing every object from every Python-backed package. The embedded Python
runtime cannot be restarted in the same process afterward.

## Architecture

```text
Tensor / top-level factories
            |
           torch
            |
       TensorPython
```
