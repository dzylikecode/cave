import 'dart:async';

Future<void> main() async {
  final timeController = StreamController<Tick>.broadcast();

  final engine = FakeEngine(timeController.stream);
  final policy = FakePolicy(engine.observations, controlEvery: 10);

  final actionSubscription = policy.actions.listen(engine.applyAction);

  // Policy 必须先订阅 observation，然后 Engine 才开始产生 observation。
  policy.start();
  engine.start();

  const dt = Duration(milliseconds: 16);

  for (var index = 0; index < 30; index++) {
    timeController.add(Tick(index: index, time: dt * index, dt: dt));

    // 给异步广播流一次处理当前 tick 的机会。
    await Future<void>.delayed(Duration.zero);
  }

  await timeController.close();
  await engine.dispose();
  await policy.dispose();
  await actionSubscription.cancel();
}

final class Tick {
  const Tick({required this.index, required this.time, required this.dt});

  final int index;
  final Duration time;
  final Duration dt;
}

final class Observation {
  const Observation({
    required this.tick,
    required this.position,
    required this.appliedAction,
  });

  final Tick tick;
  final double position;
  final Action appliedAction;
}

final class Action {
  const Action({required this.sourceTick, required this.value});

  const Action.initial() : sourceTick = -1, value = 1.0;

  // 这个动作是根据哪一个 tick 的 observation 计算出来的。
  final int sourceTick;
  final double value;
}

final class FakeEngine {
  FakeEngine(this._ticks);

  final Stream<Tick> _ticks;
  final _observationController = StreamController<Observation>.broadcast();

  Stream<Observation> get observations => _observationController.stream;

  StreamSubscription<Tick>? _tickSubscription;
  Action _currentAction = const Action.initial();
  double _position = 0;

  void start() {
    if (_tickSubscription != null) {
      throw StateError('Engine has already started.');
    }

    _tickSubscription = _ticks.listen((tick) {
      // 当前保存的 action 推进物理世界一步。
      final dtSeconds = tick.dt.inMicroseconds / Duration.microsecondsPerSecond;
      _position += _currentAction.value * dtSeconds;

      final observation = Observation(
        tick: tick,
        position: _position,
        appliedAction: _currentAction,
      );

      print(
        'engine  tick=${tick.index.toString().padLeft(2)} '
        'position=${_position.toStringAsFixed(3)} '
        'action=${_currentAction.value.toStringAsFixed(3)} '
        '(from tick ${_currentAction.sourceTick})',
      );

      // Engine 完成 step 后才发布 observation。
      _observationController.add(observation);
    });
  }

  void applyAction(Action action) {
    // 新动作从下一个物理 tick 开始生效。
    _currentAction = action;
  }

  Future<void> dispose() async {
    await _tickSubscription?.cancel();
    await _observationController.close();
  }
}

final class FakePolicy {
  FakePolicy(this._observations, {required this.controlEvery})
    : assert(controlEvery > 0);

  final Stream<Observation> _observations;
  final int controlEvery;
  final _actionController = StreamController<Action>.broadcast();

  Stream<Action> get actions => _actionController.stream;

  StreamSubscription<Observation>? _observationSubscription;

  void start() {
    if (_observationSubscription != null) {
      throw StateError('Policy has already started.');
    }

    _observationSubscription = _observations.listen((observation) {
      final tick = observation.tick;

      // Policy 以物理频率的 1 / controlEvery 运行。
      if (tick.index % controlEvery != 0) {
        return;
      }

      // 示例控制律：让 position 回到 0。
      final action = Action(
        sourceTick: tick.index,
        value: -observation.position,
      );

      print(
        'policy  tick=${tick.index.toString().padLeft(2)} '
        'new action=${action.value.toStringAsFixed(3)}',
      );

      _actionController.add(action);
    });
  }

  Future<void> dispose() async {
    await _observationSubscription?.cancel();
    await _actionController.close();
  }
}
