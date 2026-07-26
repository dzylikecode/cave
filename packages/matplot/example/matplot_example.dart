import 'package:py_embed/py_embed.dart';

void main() async {
  final py = Python.venv(await getPyExecutableFromShell());

  // import numpy as np
  final np = PyModule('numpy');

  final arange = np.get<PyFunction>('arange');
  final sin = np.get<PyFunction>('sin');
  final add = np.get<PyFunction>('add');
  final multiply = np.get<PyFunction>('multiply');
  final pi = np.get<PyDouble>('pi');

  // t = np.arange(0.0, 2.0, 0.01)
  final t = arange.call<PyObject>(
    PyTuple.fromList([
      PyDouble(0.0),
      PyDouble(2.0),
      PyDouble(0.01),
    ]),
  );

  // phase = 2 * np.pi * t
  final twoPi = multiply.call<PyObject>(
    PyTuple.fromList([
      PyDouble(2.0),
      pi,
    ]),
  );

  final phase = multiply.call<PyObject>(
    PyTuple.fromList([
      twoPi,
      t,
    ]),
  );

  // s = 1 + np.sin(phase)
  final sineValues = sin.call<PyObject>(
    PyTuple.fromList([phase]),
  );

  final s = add.call<PyObject>(
    PyTuple.fromList([
      PyDouble(1.0),
      sineValues,
    ]),
  );

  // import matplotlib.pyplot as plt
  final plt = PyModule('matplotlib.pyplot');
  final subplots = plt.get<PyFunction>('subplots');

  // fig, ax = plt.subplots()
  final result = subplots.call<PyTuple>(PyTuple(0));
  final fig = result.getItem(0);
  final ax = result.getItem(1);

  // ax.plot(t, s)
  ax.get<PyFunction>('plot').call<PyObject>(
    PyTuple.fromList([t, s]),
  );

  // ax.set(
  //   xlabel='time (s)',
  //   ylabel='voltage (mV)',
  //   title='About as simple as it gets, folks',
  // )
  final labels = PyDict()
    ..setItemString('xlabel', PyString('time (s)'))
    ..setItemString('ylabel', PyString('voltage (mV)'))
    ..setItemString(
      'title',
      PyString('About as simple as it gets, folks'),
    );

  ax.get<PyFunction>('set').call<PyObject>(
    PyTuple(0),
    labels,
  );

  // ax.grid()
  ax.get<PyFunction>('grid').call<PyObject>(
    PyTuple(0),
  );

  // fig.savefig("test.png")
  fig.get<PyFunction>('savefig').call<PyObject>(
    PyTuple.fromList([
      PyString('test.png'),
    ]),
  );

  // plt.show()
  plt.get<PyFunction>('show').call<PyObject>(
    PyTuple(0),
  );

  py.dispose();
}