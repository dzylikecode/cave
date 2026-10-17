// ignore_for_file: implementation_imports
import 'package:py_embed/py_embed.dart';
import 'package:test/test.dart';
import 'package:torch_dart/src/backend/python.dart';

void main() {
  tearDown(() => expect(ResourceScope.checkNoLeaks(), isTrue));

  test('module scope owns both the Python instance and its Dart callback', () {
    late ModulePython model;
    late PyFunction callback;
    ResourceScope.scope(() {
      model = ResourceScope.returning(() {
        callback = PyFunction((args, kwargs) => PyDouble(2.5));
        final source = PyModule.fromSource('''
class Model:
    def __init__(self, callback):
        self.callback = callback
    def __call__(self):
        return self.callback()
''');
        return ModulePython(
          source.getAttr('Model').forward([callback]),
          callback,
        );
      });
      expect(model.call([]).handle.asDouble(), 2.5);
      expect(callback.isDisposed, isFalse);
    });
    expect(model.isDisposed, isTrue);
    expect(callback.isDisposed, isTrue);
    model.dispose();
  });

  test(
    'parameters keep owned references after the temporary list is released',
    () {
      ResourceScope.scope(() {
        final source = PyModule.fromSource('''
class Model:
    def parameters(self):
        return iter([1.5, 2.5])
''');
        final model = ModulePython(source.getAttr('Model').call0());
        final parameters = model.parameters().cast<TensorPython>();
        model.dispose();
        expect(parameters.map((value) => value.handle.asDouble()), [1.5, 2.5]);
      });
    },
  );

  test('tensor operations promote results into the caller scope', () {
    late TensorPython result;
    ResourceScope.scope(() {
      final input = TensorPython(PyDouble(3.5));
      result = input + 2;
      expect(result.handle.asDouble(), 5.5);
      expect(input.handle.asDouble(), 3.5);
    });
    expect(result.handle.isDisposed, isTrue);
  });
}
