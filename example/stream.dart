import 'dart:async';

void main() async {
  final timeController = StreamController<Tick>.broadcast();
  final engine = FakeEngine(timeController);
  final policy = FakePolicy(timeController);

  policy.actions.listen((action) {
    engine.applyAction(action);
  });
  engine.sensors.listen((sensor) {
    policy.updateSensor(sensor);
  });

  engine.start();
  policy.start();

  for (var i = 0; i < 10; i++) {
    final tick = Tick(i, Duration(milliseconds: i * 16));
    timeController.add(tick);
    await Future.delayed(.zero);
  }
}

class Tick {
  final int index;
  final Duration time;

  const Tick(this.index, this.time);
}

class FakeEngine {
  final StreamController<Tick> _timeController;
  final sensorController = StreamController<int>.broadcast();
  Stream<int> get sensors => sensorController.stream;
  int steps = 0;
  int curAction = 0;
  FakeEngine(this._timeController);
  

  void start() {
    _timeController.stream.listen((tick) {
      print('world time: ${tick.index}, engine tick: $steps, applied action: $curAction');
      sensorController.add(curAction);
      steps++;
    });
  }

  void applyAction(int action) {
    curAction = action;
  }

}


class FakePolicy {
  final StreamController<Tick> _timeController;
  int steps = 0;
  final actionController = StreamController<int>.broadcast();
  Stream<int> get actions => actionController.stream;
  int curSensor = 0;
  FakePolicy(this._timeController);

  void start() {
    _timeController.stream.listen((tick) {
      print('world time: ${tick.index}, sensor: $curSensor, policy tick: $steps');
      actionController.add(steps);
      steps++;
    });
  }

  void updateSensor(int sensor) {
    curSensor = sensor;
  }
}
