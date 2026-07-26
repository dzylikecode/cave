import 'package:py_embed/py_embed.dart';

final np = PyModule('numpy');

final arange = np.get('arange');
final sin = np.get('sin');
final pi = np.get('pi');
