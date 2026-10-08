// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';
import 'package:vector_math/vector_math.dart' show Vector3, Quaternion;

import '../base.dart';

final class PythonApi implements BaseApi {
  // Isaac Gym must be imported before PyTorch.
  late final gymapi = PyModule('isaacgym.gymapi');
  @override
  Gym acquire_gym() => Py.using((scope) {
    final method = scope(gymapi.getAttr('acquire_gym'));
    return GymPython(method.call0(), this);
  });

  PyObject encode(Object? value) {
    if (value is PythonHandle) {
      value.check();
      value.handle.ref.increment();
      return value.handle;
    }
    return switch (value) {
      null => PyObject.getConst(.none),
      bool v => PyBool(v),
      int v => PyInt(v),
      double v => PyDouble(v),
      String v => PyString(v),
      SimType v => gymapi.getAttr(switch (v) {
        SimType.physx => 'SIM_PHYSX',
        SimType.flex => 'SIM_FLEX',
      }),
      StateFlags v => gymapi.getAttr(switch (v) {
        StateFlags.none => 'STATE_NONE',
        StateFlags.pos => 'STATE_POS',
        StateFlags.vel => 'STATE_VEL',
        StateFlags.all => 'STATE_ALL',
      }),
      MeshType _ => gymapi.getAttr('MESH_VISUAL_AND_COLLISION'),
      KeyboardInput _ => gymapi.getAttr('KEY_R'),
      Vector3 v => construct('Vec3', [v.x, v.y, v.z]),
      Quaternion v => construct('Quat', [v.x, v.y, v.z, v.w]),
      Transform v => config('Transform', {'p': v.p, 'r': v.r}),
      PlaneParams _ => construct('PlaneParams', []),
      CameraProperties _ => construct('CameraProperties', []),
      AssetOptions _ => construct('AssetOptions', []),
      SimParams v => simParams(v),
      _ => throw ArgumentError(
        'Unsupported Python argument: ${value.runtimeType}',
      ),
    };
  }

  PyObject call(PyObject object, String name, List<Object?> values) =>
      Py.using((scope) {
        final method = scope(object.getAttr(name));
        final args = scope(PyTuple(values.length));
        for (var i = 0; i < values.length; i++) {
          // The tuple consumes each newly encoded reference.
          args.setElementAt(i, encode(values[i]));
        }
        return method.call(args);
      });

  PyObject construct(String name, List<Object?> values) =>
      call(gymapi, name, values);

  void fields(PyObject object, Map<String, Object?> values) =>
      Py.using((scope) {
        for (final entry in values.entries) {
          if (entry.value != null) {
            object.setAttr(entry.key, scope(encode(entry.value)));
          }
        }
      });

  PyObject config(String name, Map<String, Object?> values) =>
      Py.using((scope) {
        final result = scope(construct(name, []));
        fields(result, values);
        return scope.escape(result);
      });

  PyObject simParams(SimParams v) => Py.using((scope) {
    final result = scope(
      config('SimParams', {
        'dt': v.dt,
        'substeps': v.substeps,
        'use_gpu_pipeline': v.use_gpu_pipeline,
      }),
    );
    fields(scope(result.getAttr('physx')), {
      'solver_type': v.physx.solver_type,
      'num_position_iterations': v.physx.num_position_iterations,
      'num_velocity_iterations': v.physx.num_velocity_iterations,
      'num_threads': v.physx.num_threads,
      'use_gpu': v.physx.use_gpu,
    });
    fields(scope(result.getAttr('flex')), {
      'shape_collision_margin': v.flex.shape_collision_margin,
      'num_outer_iterations': v.flex.num_outer_iterations,
      'num_inner_iterations': v.flex.num_inner_iterations,
    });
    return scope.escape(result);
  });
}

class PythonHandle {
  final PyObject handle;
  final PythonHandle? owner;
  bool _disposed = false;
  PythonHandle(this.handle, [this.owner]);
  void check() {
    if (_disposed) throw StateError('$runtimeType has been disposed');
    owner?.check();
  }

  void release() {
    if (_disposed) return;
    _disposed = true;
    handle.ref.discrement();
  }
}

final class SimPython extends PythonHandle implements Sim {
  final children = <PythonHandle>[];
  SimPython(super.handle, super.owner);
}

final class EnvPython extends PythonHandle implements Env {
  EnvPython(super.handle, SimPython super.owner);
}

final class AssetPython extends PythonHandle implements Asset {
  AssetPython(super.handle, SimPython super.owner);
}

final class ViewerPython extends PythonHandle implements Viewer {
  ViewerPython(super.handle, SimPython super.owner);
}

final class RigidBodyStatesPython extends PythonHandle
    implements RigidBodyStates {
  RigidBodyStatesPython(super.handle, [super.owner]);
  @override
  int get length => Py.using((scope) {
    check();
    final method = scope(handle.getAttr('__len__'));
    return scope(method.call0()).asInt();
  });

  @override
  RigidBodyStates copy() => Py.using((scope) {
    check();
    final method = scope(handle.getAttr('copy'));
    return RigidBodyStatesPython(method.call0());
  });

  @override
  void dispose() => release();
}

final class GymPython extends PythonHandle implements Gym {
  final PythonApi api;
  final _sims = <SimPython>[];
  GymPython(super.handle, this.api);
  PyObject invoke(String name, List<Object?> args) {
    check();
    for (final arg in args.whereType<PythonHandle>()) {
      arg.check();
      PythonHandle root = arg;
      while (root.owner != null) {
        root = root.owner!;
      }
      if (root is GymPython && !identical(root, this)) {
        throw ArgumentError('Object belongs to another Gym wrapper');
      }
    }
    return api.call(handle, name, args);
  }

  PyObject requiredResult(String name, List<Object?> args) {
    final result = invoke(name, args);
    final isNone = result.ptr == PyObject.borrowedConst(.none).ptr;
    if (isNone) {
      result.ref.discrement();
      throw StateError('$name returned None');
    }
    return result;
  }

  @override
  Sim create_sim(
    int compute_device_id,
    int graphics_device_id,
    SimType type,
    SimParams params,
  ) {
    final sim = SimPython(
      requiredResult('create_sim', [
        compute_device_id,
        graphics_device_id,
        type,
        params,
      ]),
      this,
    );
    _sims.add(sim);
    return sim;
  }

  @override
  Viewer create_viewer(covariant SimPython sim, CameraProperties properties) {
    final viewer = ViewerPython(
      requiredResult('create_viewer', [sim, properties]),
      sim,
    );
    sim.children.add(viewer);
    return viewer;
  }

  @override
  Asset load_asset(
    covariant SimPython sim,
    String root,
    String file,
    AssetOptions options,
  ) {
    final asset = AssetPython(
      requiredResult('load_asset', [sim, root, file, options]),
      sim,
    );
    sim.children.add(asset);
    return asset;
  }

  @override
  Env create_env(
    covariant SimPython sim,
    Vector3 lower,
    Vector3 upper,
    int num_per_row,
  ) {
    if (num_per_row <= 0) throw ArgumentError.value(num_per_row, 'num_per_row');
    final env = EnvPython(
      requiredResult('create_env', [sim, lower, upper, num_per_row]),
      sim,
    );
    sim.children.add(env);
    return env;
  }

  @override
  int create_actor(
    covariant EnvPython env,
    covariant AssetPython asset,
    Transform pose,
    String? name,
    int collision_group,
    int collision_filter,
  ) {
    if (!identical(env.owner, asset.owner)) {
      throw ArgumentError(
        'Environment and asset must belong to the same simulation',
      );
    }
    final actor = Py.using((scope) {
      final v = scope(
        invoke('create_actor', [
          env,
          asset,
          pose,
          name,
          collision_group,
          collision_filter,
        ]),
      );
      return v.asInt();
    });
    if (actor < 0) throw StateError('create_actor failed');
    return actor;
  }

  @override
  RigidBodyStates get_sim_rigid_body_states(
    covariant SimPython sim,
    StateFlags flags,
  ) {
    final states = RigidBodyStatesPython(
      requiredResult('get_sim_rigid_body_states', [sim, flags]),
      sim,
    );
    sim.children.add(states);
    return states;
  }

  @override
  List<ActionEvent> query_viewer_action_events(Viewer viewer) =>
      Py.using((scope) {
        final events = scope(invoke('query_viewer_action_events', [viewer]));
        final length = scope(events.getAttr('__len__'));
        final count = scope(length.call0()).asInt();
        return List.generate(count, (i) {
          final event = scope(events.getItem(scope(PyInt(i))));
          return ActionEvent(
            event.getAttrString('action'),
            event.getAttrDouble('value'),
          );
        });
      });
  @override
  void destroy_viewer(covariant ViewerPython viewer) {
    if (viewer._disposed) return;
    invoke('destroy_viewer', [viewer]).ref.discrement();
    viewer.release();
  }

  @override
  void destroy_sim(covariant SimPython sim) {
    if (sim._disposed) return;
    sim.check();
    for (final viewer in sim.children.whereType<ViewerPython>()) {
      destroy_viewer(viewer);
    }
    invoke('destroy_sim', [sim]).ref.discrement();
    for (final child in sim.children) {
      child.release();
    }
    sim.children.clear();
    sim.release();
    _sims.remove(sim);
  }

  @override
  void dispose() {
    if (_sims.isNotEmpty) {
      throw StateError('Destroy simulations before disposing Gym');
    }
    release();
  }

  @override
  void add_ground(Sim sim, PlaneParams params) =>
      invoke('add_ground', [sim, params]).ref.discrement();
  @override
  void set_rigid_body_color(
    Env env,
    int actor,
    int body,
    MeshType mesh,
    Vector3 color,
  ) => invoke('set_rigid_body_color', [
    env,
    actor,
    body,
    mesh,
    color,
  ]).ref.discrement();
  @override
  void subscribe_viewer_keyboard_event(
    Viewer viewer,
    KeyboardInput key,
    String action,
  ) => invoke('subscribe_viewer_keyboard_event', [
    viewer,
    key,
    action,
  ]).ref.discrement();
  @override
  void viewer_camera_look_at(
    Viewer viewer,
    Env? env,
    Vector3 position,
    Vector3 target,
  ) => invoke('viewer_camera_look_at', [
    viewer,
    env,
    position,
    target,
  ]).ref.discrement();
  @override
  bool set_sim_rigid_body_states(
    Sim sim,
    RigidBodyStates states,
    StateFlags flags,
  ) => Py.using((scope) {
    final v = scope(invoke('set_sim_rigid_body_states', [sim, states, flags]));
    return v.asBool();
  });
  @override
  bool query_viewer_has_closed(Viewer viewer) => Py.using((scope) {
    final v = scope(invoke('query_viewer_has_closed', [viewer]));
    return v.asBool();
  });
  @override
  void simulate(Sim sim) => invoke('simulate', [sim]).ref.discrement();
  @override
  void fetch_results(Sim sim, bool wait) =>
      invoke('fetch_results', [sim, wait]).ref.discrement();
  @override
  void step_graphics(Sim sim) =>
      invoke('step_graphics', [sim]).ref.discrement();
  @override
  void draw_viewer(Viewer viewer, Sim sim, bool sync) =>
      invoke('draw_viewer', [viewer, sim, sync]).ref.discrement();
  @override
  void sync_frame_time(Sim sim) =>
      invoke('sync_frame_time', [sim]).ref.discrement();
}
