import 'package:py_embed/py_embed.dart';
import 'package:num_py/num_py.dart';


void main() async {
  final py = Python.venv(await getPyExecutableFromShell());

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
  final PyTuple result = plt.get('subplots').call(PyTuple()).cast();
  final fig = result.getItem(0);
  final ax = result.getItem(1);

  // ax.plot(t, s)
  ax.get('plot')(PyTuple.fromList([t, s]));

  // ax.set(...)
  final labels = PyDict()
    ..setItemString('xlabel', PyString('time (s)'))
    ..setItemString('ylabel', PyString('voltage (mV)'))
    ..setItemString('title', PyString('About as simple as it gets, folks'));

  ax.get('set')(PyTuple(0), labels);

  // ax.grid()
  ax.get('grid')(PyTuple(0));

  // fig.savefig("test.png")
  fig.get('savefig')(PyTuple.fromList([PyString('test.png')]));

  // plt.show()
  plt.get('show')(PyTuple(0));

  py.dispose();
}
