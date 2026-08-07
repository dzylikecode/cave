import 'dart:async';

void main() async {
  final timeController = StreamController<void>.broadcast();
  final engine = FakeEngine();
  final policy = FakePolicy();

  policy.actions.listen((action) {
    engine.applyAction(action.force);
  });

  engine.start(timeController.stream);
  policy.start(engine.state);

  for (var i = 0; i < 10; i++) {
    timeController.add(null);
    await Future.delayed(.zero);
  }
}

class Observation {
  final int physicalState;
  const Observation({required this.physicalState});
}

class FakeEngine {
  final stateController = StreamController<Observation>.broadcast();
  Stream<Observation> get state => stateController.stream;
  int steps = 0;
  String curAction = '';
  FakeEngine();

  void start(Stream<void> ticks) {
    ticks.listen((_) {
      print(
        'engine tick: $steps, applied action: $curAction',
      );
      steps++;
      stateController.add(Observation(physicalState: steps));
    });
  }

  void applyAction(String action) {
    curAction = action;
  }
}

class Action {
  final Observation observation;
  final String force;
  const Action({required this.observation, required this.force});
}

class FakePolicy {
  final actionController = StreamController<Action>.broadcast();
  Stream<Action> get actions => actionController.stream;
  FakePolicy();

  void start(Stream<Observation> observation) {
    observation.listen((obs) {
      final force = 'force_${obs.physicalState}';
      print('policy: ${obs.physicalState} -> $force');
      actionController.add(Action(observation: obs, force: force));
    });
  }
}
