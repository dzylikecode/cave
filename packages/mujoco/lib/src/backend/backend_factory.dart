import 'backend.dart';
import 'python/python_backend.dart';

MujocoBackend? _backend;

MujocoBackend get mujocoBackend => _backend ??= createMujocoBackend();

MujocoBackend createMujocoBackend() => PythonMujocoBackend();
