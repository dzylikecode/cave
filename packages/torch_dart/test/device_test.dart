import 'package:test/test.dart';
import 'package:torch_dart/src/base.dart';

void main() {
  test('parses device types and optional indices', () {
    for (final type in DeviceType.values) {
      expect(Device.parse(type.name), Device(type));
      expect(Device.parse('${type.name}:0'), Device(type, index: 0));
      expect(Device.parse('${type.name}:12'), Device(type, index: 12));
    }
  });

  test('rejects invalid devices with the failing input as source', () {
    for (final (value, source) in [
      ('', ''),
      ('unknown', 'unknown'),
      ('unknown:0', 'unknown'),
      ('cuda:0:1', 'cuda:0:1'),
      ('cuda:', ''),
      (':0', ''),
      ('cuda:abc', 'abc'),
      ('cuda:1.5', '1.5'),
      ('cuda:999999999999999999999999999999', '999999999999999999999999999999'),
    ]) {
      expect(
        () => Device.parse(value),
        throwsA(
          isA<FormatException>().having((e) => e.source, 'source', source),
        ),
        reason: value,
      );
    }
  });

  test('parses index formats supported by int.parse', () {
    for (final value in ['cuda:+1', 'cuda: 1', 'cuda:0x1']) {
      expect(Device.parse(value), Device(DeviceType.cuda, index: 1));
    }
  });

  test('asserts that the index is nonnegative', () {
    expect(() => Device.parse('cuda:-1'), throwsA(isA<AssertionError>()));
  });

  test('unknown device types throw FormatException', () {
    expect(
      () => DeviceType.fromString('unknown'),
      throwsA(
        isA<FormatException>().having((e) => e.source, 'source', 'unknown'),
      ),
    );
  });
}
