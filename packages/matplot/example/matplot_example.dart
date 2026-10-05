import 'package:py_embed/py_embed.dart';
import 'package:num_py/num_py.dart';

void main() async {
  // t = np.arange(0.0, 2.0, 0.01)
  final t = arange(
    PyTuple.fromList([PyDouble(0.0), PyDouble(2.0), PyDouble(0.01)]),
  );

  // s = 1 + np.sin(2 * np.pi * t)
  final phase = PyDouble(2.0) * pi * t;
  final sineValues = sin(PyTuple.fromList([phase]));
  final s = PyDouble(1.0) + sineValues;

  // import matplotlib.pyplot as plt
  final plt = PyModule('matplotlib.pyplot');

  // fig, ax = plt.subplots()
  final PyTuple result = .fromHandle(plt.getAttr('subplots').call0().ptr);
  final fig = result[0];
  final ax = result[1];

  // ax.plot(t, s)
  ax.getAttr('plot')(PyTuple.fromList([t, s]));

  // ax.set(...)
  final labels = PyDict()
    ..setAttr('xlabel', PyString('time (s)'))
    ..setAttr('ylabel', PyString('voltage (mV)'))
    ..setAttr('title', PyString('About as simple as it gets, folks'));

  ax.getAttr('set')(PyTuple(0), labels);

  // ax.grid()
  ax.getAttr('grid')(PyTuple(0));

  // fig.savefig("test.png")
  fig.getAttr('savefig')(PyTuple.fromList([PyString('test.png')]));

  // plt.show()
  // plt.getAttr('show')(PyTuple(0));
}
