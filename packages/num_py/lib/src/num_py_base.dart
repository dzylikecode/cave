import 'package:py_embed/py_embed.dart';

final np = PyModule('numpy');

final arange = np.getAttr('arange');
final sin = np.getAttr('sin');
final pi = np.getAttr('pi');
