/// https://docs.python.org/3/extending/embedding.html
library;

export 'src/config.dart' hide StringToWCharExt, WCharExt;
export 'src/exception.dart' show PythonException;
export 'src/venv.dart' hide extractVersion;
export 'src/vm.dart' show Python;
export 'src/object.dart';
