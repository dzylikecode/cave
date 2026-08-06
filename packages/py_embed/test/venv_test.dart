import 'package:test/test.dart';
import 'package:py_embed/src/venv.dart';

void main() {
  test('extract version', () {
    expect(extractVersion('Python 3.8.10'), (3, 8, 10));
  });

  test('get python version from shell', () {
    expect(getPyVersionSync(), (3, 8, 10));
  });

  test('get python dll path from shell', () {
    expect(() => getPyDllPathSync(), returnsNormally);
  });
}
