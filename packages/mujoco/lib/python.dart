/// Python object interoperability for integrations such as the passive viewer.
///
/// Applications should use mujoco.dart. These wrappers expose Python handles
/// only for libraries that need to pass the original objects to Python APIs.
library;

export 'src/backend/python.dart' show MjModelPython, MjDataPython;
