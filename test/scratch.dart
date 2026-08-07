/// a scratch, 希望代码与数学原理对齐
///
/// physical: $s(n+1) = f(s(n), a(n))$
/// 
/// policy: $a(n) = \pi(s(n))$
/// 
/// 物理世界产生的信息是已经发生的，状态可以被刻画为:
/// 
/// ```
/// (a(n) -> s(n+1))
///   |       |
///   |       |
///  原因     后果
/// ```
/// 
/// policy 根据观测来决策，可以被刻画为:
/// 
/// ```
/// (s(n) -> a(n))
///   |       |
///   |       |
///  观测    决策
/// ```
/// 
/// 于是可以视为这么两条纠缠的流
/// 
/// ```
/// physical: (a(0) -> s(1))  (a(1) -> s(2))  (a(2) -> s(3))  ...
///                     |       ^       |       ^       |       ^
///                     V       |       V       |       V       |
/// policy:           (s(1) -> a(1))  (s(2) -> a(2))  (s(3) -> a(3))  ...
/// 
/// ```
/// 
/// 时间穿流而过
/// 
/// 
library;


import 'dart:async';
import 'package:test/test.dart';

void main() async {
  final engine = Engine();
  final policy = Policy();

  final timerController = StreamController<void>.broadcast();

  policy.actions.listen((action) {
    engine.apply(action.force);
  });

  engine.start(timerController.stream);
  policy.start(engine.state);

  engine.state.listen((state) {
    print('engine state: $state');
  });

  policy.actions.listen((action) {
    print('policy action: $action');
  });


  for (int i = 0; i < 5; i++) {
    timerController.add(null);
    await Future.delayed(.zero);
  }

  // engine.dispose();
  // policy.dispose();
  // timerController.close();
}


/// s(n)
class EngineState {
  final int state;
  final Force force;
  const EngineState({required this.state, required this.force});

  String toString() => 's($state) = f(a(${force.value}))';
}

/// a(n)
class Force {
  final int value;
  const Force({required this.value});

  String toString() => 'a($value)';
}


/// 产生的信息是已经发生的
/// 
/// (s(n+1), a(n))
///     |     |
///     |     |
///   后果    原因
class Engine {
  final stateController = StreamController<EngineState>.broadcast();
  Stream<EngineState> get state => stateController.stream;
  EngineState get currentState => EngineState(state: steps, force: curForce);
  int steps = 0;
  var curForce = Force(value: 0);
  Engine();
  StreamSubscription<void>? _subscription;

  void start(Stream<void> ticks) {
    _subscription = ticks.listen((_) {
      steps++; // s(n+1) = f(s(n), a(n))
      stateController.add(EngineState(state: steps, force: curForce));
    });
  }

  void apply(Force force) {
    curForce = force;
  }

  void dispose() {
    _subscription?.cancel();
    stateController.close();
  }
}


class PolicyState {
  final EngineState observation;
  final Force force;
  const PolicyState({required this.observation, required this.force});

  String toString() => 'a(${force.value}) = pi(s(${observation.state}))';
}


/// 根据观测来决策
/// 
/// (s(n), a(n))
///   |     |
///   |     |
///  观测  决策
class Policy {
  final actionController = StreamController<PolicyState>.broadcast();
  Stream<PolicyState> get actions => actionController.stream;
  Policy();

  StreamSubscription<EngineState>? _subscription;
  void start(Stream<EngineState> observations) {
    _subscription = observations.listen((obs) {
      // a(n) = pi(s(n))
      final force = Force(value: obs.state);
      actionController.add(PolicyState(observation: obs, force: force));
    });
  }

  void dispose() {
    _subscription?.cancel();
    actionController.close();
  }
}
