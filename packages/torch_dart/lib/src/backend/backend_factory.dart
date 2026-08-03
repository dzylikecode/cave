import 'backend.dart';
import 'python/backend.dart';

Torch? _torch;

Torch get torch => _torch ??= createTorch();

Torch createTorch() => TorchPython();
