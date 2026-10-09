// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';
import 'package:vector_math/vector_math.dart' show Vector3, Quaternion;

import '../base.dart';

final class PythonApi() implements BaseApi {
  // Isaac Gym must be imported before PyTorch.
  late final gymapi = PyModule('isaacgym.gymapi');
  @override
  Gym acquire_gym() => Py.using((scope) {
    final method = scope(gymapi.getAttr('acquire_gym'));
    return GymPython(method.call0(), this);
  });

  late final converter = GymConverter(gymapi);
}

/// Only Gym-specific types are converted here; py_embed handles the rest.
final class GymConverter(final PyObject gymapi) extends PyConverter {
  @override
  PyObject toPyObject(Object? value) {
    return switch (value) {
      SimType v => gymapi.getAttr(switch (v) {
        .physx => 'SIM_PHYSX',
        .flex => 'SIM_FLEX',
      }),
      StateFlags v => gymapi.getAttr(switch (v) {
        .none => 'STATE_NONE',
        .pos => 'STATE_POS',
        .vel => 'STATE_VEL',
        .all => 'STATE_ALL',
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
      _ => super.toPyObject(value),
    };
  }

  PyObject construct(String name, List<Object?> values) => Py.using((scope) {
    final constructor = scope(gymapi.getAttr(name));
    return constructor.forward(values, converter: this);
  });

  void fields(PyObject object, Map<String, Object?> values) =>
      Py.using((scope) {
        for (final entry in values.entries) {
          if (entry.value != null) {
            object.setAttr(entry.key, scope(toPyObject(entry.value)));
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

class PythonHandle(@override final PyObject handle) implements PyObjectWrapper {
  void release() => handle.ref.discrement();
}

final class SimPython extends PythonHandle implements Sim {
  // Env and Asset have no public dispose(); the simulation owns their wrappers.
  final children = <PythonHandle>[];
  SimPython(super.handle);
}

final class EnvPython(super.handle) extends PythonHandle implements Env;
final class AssetPython(super.handle) extends PythonHandle implements Asset;
final class ViewerPython(super.handle) extends PythonHandle implements Viewer;

final class RigidBodyStatesPython(super.handle)
    extends PythonHandle
    implements RigidBodyStates {
  @override
  int get length => Py.len(handle);

  @override
  RigidBodyStatesPython copy() => Py.using((scope) {
    final method = scope(handle.getAttr('copy'));
    return RigidBodyStatesPython(method.call0());
  });

  @override
  void dispose() => release();
}

final class GymPython extends PythonHandle implements Gym {
  final PythonApi api;
  GymPython(super.handle, this.api);

  PyObject invoke(String name, List<Object?> args) => Py.using((scope) {
    final method = scope(handle.getAttr(name));
    return method.forward(args, converter: api.converter);
  });

  @override
  Sim create_sim(
    int compute_device_id,
    int graphics_device_id,
    SimType type,
    SimParams params,
  ) => SimPython(
    invoke('create_sim', [compute_device_id, graphics_device_id, type, params]),
  );

  @override
  Viewer create_viewer(Sim sim, CameraProperties properties) =>
      ViewerPython(invoke('create_viewer', [sim, properties]));

  @override
  Asset load_asset(
    covariant SimPython sim,
    String root,
    String file,
    AssetOptions options,
  ) {
    final asset = AssetPython(invoke('load_asset', [sim, root, file, options]));
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
    final env = EnvPython(
      invoke('create_env', [sim, lower, upper, num_per_row]),
    );
    sim.children.add(env);
    return env;
  }

  @override
  int create_actor(
    Env env,
    Asset asset,
    Transform pose,
    String? name,
    int collision_group,
    int collision_filter,
  ) => Py.using((scope) {
    return scope(
      invoke('create_actor', [
        env,
        asset,
        pose,
        name,
        collision_group,
        collision_filter,
      ]),
    ).asInt();
  });

  @override
  RigidBodyStates get_sim_rigid_body_states(Sim sim, StateFlags flags) =>
      RigidBodyStatesPython(invoke('get_sim_rigid_body_states', [sim, flags]));

  @override
  List<ActionEvent> query_viewer_action_events(Viewer viewer) =>
      Py.using((scope) {
        final events = scope(invoke('query_viewer_action_events', [viewer]));
        final count = Py.len(events);
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
    invoke('destroy_viewer', [viewer]).ref.discrement();
    viewer.release();
  }

  @override
  void destroy_sim(covariant SimPython sim) {
    invoke('destroy_sim', [sim]).ref.discrement();
    for (final child in sim.children) {
      child.release();
    }
    sim.children.clear();
    sim.release();
  }

  @override
  void dispose() => release();

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
