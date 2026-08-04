import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';

void main() {
  tearDownAll(Python.shutdown);

  Python.runSimpleString(r'''
class DartTestContext:
    def __init__(self):
        self.entered = False
        self.exited = False
        self.exit_args = None

    def __enter__(self):
        self.entered = True
        return "entered value"

    def __exit__(self, exc_type, exc_value, traceback):
        self.exited = True
        self.exit_args = (exc_type, exc_value, traceback)
        return False

dart_test_context = DartTestContext()
''');

  late PyModule mainModule;
  late PyObject context;

  setUp(() {
    mainModule = PyModule('__main__');
    context = mainModule.get('dart_test_context');
  });

  tearDown(() {
    context.dispose();
    mainModule.dispose();
  });

  test('passes the value returned by __enter__ and calls __exit__', () {
    final result = context.withContext((value) => value.toDartString());

    expect(result, 'entered value');
    expect(context.getBool('entered'), isTrue);
    expect(context.getBool('exited'), isTrue);
  });

  test('calls __exit__ and preserves a Dart exception', () {
    expect(
      () => context.withContext<void>((_) => throw StateError('failed')),
      throwsA(isA<StateError>()),
    );

    expect(context.getBool('exited'), isTrue);
    final exitArgs = context.get('exit_args');
    try {
      expect(exitArgs.str, '(None, None, None)');
    } finally {
      exitArgs.dispose();
    }
  });
}
