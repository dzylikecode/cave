// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';

import '../base.dart';

final class PythonApi implements BaseApi {
  // Isaac Gym must be imported before PyTorch.
  late final gymapi = PyModule('isaacgym.gymapi');
  @override
  Gym acquire_gym() => GymPython(
    gymapi.getAttr('acquire_gym').using((method) => method.call0()),
    this,
  );

  PyObject encode(Object? value) {
    if (value is PythonHandle) {
      value.check();
      value.handle.ref.increment();
      return value.handle;
    }
    return switch (value) {
      null => PyNone()..ref.increment(),
      bool v => PyBool(v),
      int v => PyInt(v),
      double v => PyDouble(v),
      String v => PyString(v),
      SimType v => gymapi.getAttr(v == SIM_PHYSX ? 'SIM_PHYSX' : 'SIM_FLEX'),
      MeshType _ => gymapi.getAttr('MESH_VISUAL_AND_COLLISION'),
      KeyboardInput _ => gymapi.getAttr('KEY_R'),
      Vec3 v => construct('Vec3', [v.x, v.y, v.z]),
      Quat v => construct('Quat', [v.x, v.y, v.z, v.w]),
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

  // Each encoded argument owns one reference, consumed by callN.
  PyObject call(PyObject object, String name, List<Object?> values) =>
      object.getAttr(name).using((method) {
        final args = <PyObject>[];
        try {
          for (final value in values) {
            args.add(encode(value));
          }
        } catch (_) {
          for (final arg in args) {
            arg.ref.discrement();
          }
          rethrow;
        }
        return method.callN(args);
      });
  PyObject construct(String name, List<Object?> values) =>
      call(gymapi, name, values);
  void fields(PyObject object, Map<String, Object?> values) {
    for (final entry in values.entries) {
      if (entry.value != null) {
        encode(entry.value).using((value) => object.setAttr(entry.key, value));
      }
    }
  }

  PyObject config(String name, Map<String, Object?> values) {
    final result = construct(name, []);
    try {
      fields(result, values);
      return result;
    } catch (_) {
      result.ref.discrement();
      rethrow;
    }
  }

  PyObject simParams(SimParams v) {
    final result = config('SimParams', {
      'dt': v.dt,
      'substeps': v.substeps,
      'use_gpu_pipeline': v.use_gpu_pipeline,
    });
    try {
      result
          .getAttr('physx')
          .using(
            (obj) => fields(obj, {
              'solver_type': v.physx.solver_type,
              'num_position_iterations': v.physx.num_position_iterations,
              'num_velocity_iterations': v.physx.num_velocity_iterations,
              'num_threads': v.physx.num_threads,
              'use_gpu': v.physx.use_gpu,
            }),
          );
      result
          .getAttr('flex')
          .using(
            (obj) => fields(obj, {
              'shape_collision_margin': v.flex.shape_collision_margin,
              'num_outer_iterations': v.flex.num_outer_iterations,
              'num_inner_iterations': v.flex.num_inner_iterations,
            }),
          );
      return result;
    } catch (_) {
      result.ref.discrement();
      rethrow;
    }
  }
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
  int get length {
    check();
    return handle
        .getAttr('__len__')
        .using((m) => m.call0().using((v) => v.asInt()));
  }

  @override
  RigidBodyStates copy() {
    check();
    return RigidBodyStatesPython(
      handle.getAttr('copy').using((m) => m.call0()),
    );
  }

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
    final isNone = result.ptr == PyNone().ptr;
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
    Vec3 lower,
    Vec3 upper,
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
    final actor = invoke('create_actor', [
      env,
      asset,
      pose,
      name,
      collision_group,
      collision_filter,
    ]).using((v) => v.asInt());
    if (actor < 0) throw StateError('create_actor failed');
    return actor;
  }

  @override
  RigidBodyStates get_sim_rigid_body_states(
    covariant SimPython sim,
    int flags,
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
      invoke('query_viewer_action_events', [viewer]).using((events) {
        final count = events
            .getAttr('__len__')
            .using((m) => m.call0().using((v) => v.asInt()));
        return List.generate(
          count,
          (i) => PyInt(i).using(
            (index) => events
                .getItem(index)
                .using(
                  (event) => ActionEvent(
                    event.getAttrString('action'),
                    event.getAttrDouble('value'),
                  ),
                ),
          ),
        );
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
    Vec3 color,
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
    Vec3 position,
    Vec3 target,
  ) => invoke('viewer_camera_look_at', [
    viewer,
    env,
    position,
    target,
  ]).ref.discrement();
  @override
  bool set_sim_rigid_body_states(Sim sim, RigidBodyStates states, int flags) =>
      invoke('set_sim_rigid_body_states', [
        sim,
        states,
        flags,
      ]).using((v) => v.asBool());
  @override
  bool query_viewer_has_closed(Viewer viewer) =>
      invoke('query_viewer_has_closed', [viewer]).using((v) => v.asBool());
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
