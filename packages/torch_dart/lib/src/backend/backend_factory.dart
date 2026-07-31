import 'backend.dart';
import 'python/python_backend.dart';

TorchBackend? _backend;

TorchBackend get torchBackend => _backend ??= PythonTorchBackend();
