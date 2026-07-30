import 'package:py_embed/py_embed.dart';

void main() {
  final value = PyString('hello');
  print(value.value);
}
