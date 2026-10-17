// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';
import 'package:torch_dart/torch_dart.dart' show Tensor;
// ignore: implementation_imports
import 'package:torch_dart/src/backend/python.dart' show TensorPython;
import 'package:vector_math/vector_math.dart' show Vector3, Quaternion;

import '../base.dart';

final class PythonApi() implements BaseApi {
  // Isaac Gym must be imported before PyTorch.
  late final gymapi = ResourceScope.unmanaged(
    () => PyModule('isaacgym.gymapi'),
  );
  @override
  Gym acquire_gym() => ResourceScope.scope(() {
    final method = gymapi.getAttr('acquire_gym');
    return GymPython(method.call0().detachToParentScope(), this);
  });

  late final gymtorch = ResourceScope.unmanaged(
    () => PyModule('isaacgym.gymtorch'),
  );

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
      KeyboardInput v => gymapi.getAttr(v == .r ? 'KEY_R' : 'KEY_ESCAPE'),
      UpAxis v => gymapi.getAttr(v == .z ? 'UP_AXIS_Z' : 'UP_AXIS_Y'),
      DofDriveMode v => gymapi.getAttr('DOF_MODE_${v.name.toUpperCase()}'),
      IndexDomain v => gymapi.getAttr('DOMAIN_${v.name.toUpperCase()}'),
      Vector3 v => construct('Vec3', [v.x, v.y, v.z]),
      Quaternion v => construct('Quat', [v.x, v.y, v.z, v.w]),
      Transform v => config('Transform', {'p': v.p, 'r': v.r}),
      PlaneParams v => config('PlaneParams', {
        'normal': v.normal,
        'static_friction': v.static_friction,
        'dynamic_friction': v.dynamic_friction,
        'restitution': v.restitution,
      }),
      CameraProperties _ => construct('CameraProperties', []),
      AssetOptions v => config('AssetOptions', {
        'fix_base_link': v.fix_base_link,
        'collapse_fixed_joints': v.collapse_fixed_joints,
        'disable_gravity': v.disable_gravity,
        'flip_visual_attachments': v.flip_visual_attachments,
        'replace_cylinder_with_capsule': v.replace_cylinder_with_capsule,
        'density': v.density,
        'angular_damping': v.angular_damping,
        'linear_damping': v.linear_damping,
        'armature': v.armature,
        'thickness': v.thickness,
        'default_dof_drive_mode': v.default_dof_drive_mode,
      }),
      SimParams v => simParams(v),
      _ => super.toPyObject(value),
    };
  }

  PyObject construct(String name, List<Object?> values) =>
      ResourceScope.returning(() {
        final constructor = gymapi.getAttr(name);
        return constructor.forward(values, converter: this);
      });

  void fields(PyObject object, Map<String, Object?> values) =>
      ResourceScope.scope(() {
        for (final entry in values.entries) {
          if (entry.value != null) {
            object.setAttr(entry.key, toPyObject(entry.value));
          }
        }
      });

  PyObject config(String name, Map<String, Object?> values) =>
      ResourceScope.returning(() {
        final result = construct(name, []);
        fields(result, values);
        return result;
      });

  PyObject simParams(SimParams v) => ResourceScope.returning(() {
    final result = config('SimParams', {
      'up_axis': v.up_axis,
      'gravity': v.gravity,
      'dt': v.dt,
      'substeps': v.substeps,
      'use_gpu_pipeline': v.use_gpu_pipeline,
    });
    fields(result.getAttr('physx'), {
      'solver_type': v.physx.solver_type,
      'num_position_iterations': v.physx.num_position_iterations,
      'num_velocity_iterations': v.physx.num_velocity_iterations,
      'num_threads': v.physx.num_threads,
      'use_gpu': v.physx.use_gpu,
    });
    fields(result.getAttr('flex'), {
      'shape_collision_margin': v.flex.shape_collision_margin,
      'num_outer_iterations': v.flex.num_outer_iterations,
      'num_inner_iterations': v.flex.num_inner_iterations,
    });
    return result;
  });
}

class PythonHandle(@override final PyObject handle) implements PyObjectWrapper {
  void release() => handle.dispose();
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
  int get length => len(handle);

  @override
  RigidBodyStatesPython copy() => ResourceScope.scope(() {
    final method = handle.getAttr('copy');
    return RigidBodyStatesPython(method.call0().detachToParentScope());
  });

  @override
  void dispose() => release();
}

final class GymArrayPython(super.handle)
    extends PythonHandle
    implements GymArray {
  @override
  int get length => len(handle);
  @override
  List<double> field(String name) => ResourceScope.scope(() {
    final column = handle.getItem(PyString(name));
    return List.generate(
      len(column),
      (i) => column.getItem(PyInt(i)).asDouble(),
    );
  });
  @override
  void setField(String name, List<num> values) => ResourceScope.scope(() {
    if (values.length != length) throw ArgumentError('Expected $length values');
    handle.setItem(PyString(name), PyConverter().toPyObject(values));
  });
  @override
  GymArray copy() => ResourceScope.scope(() {
    final method = handle.getAttr('copy');
    return GymArrayPython(method.call0().detachToParentScope());
  });
  @override
  void dispose() => release();
}

final class GymPython extends PythonHandle implements Gym {
  final PythonApi api;
  GymPython(super.handle, this.api);

  @override
  int get_asset_dof_count(Asset asset) =>
      ResourceScope.scope(() => invoke('get_asset_dof_count', [asset]).asInt());
  @override
  int get_asset_rigid_body_count(Asset asset) => ResourceScope.scope(
    () => invoke('get_asset_rigid_body_count', [asset]).asInt(),
  );
  @override
  int get_asset_rigid_shape_count(Asset asset) => ResourceScope.scope(
    () => invoke('get_asset_rigid_shape_count', [asset]).asInt(),
  );
  @override
  List<String> get_asset_dof_names(Asset asset) => ResourceScope.scope(() {
    final result = invoke('get_asset_dof_names', [asset]);
    return List.generate(
      len(result),
      (i) => result.getItem(PyInt(i)).asString(),
    );
  });
  @override
  List<String> get_asset_rigid_body_names(Asset asset) =>
      ResourceScope.scope(() {
        final result = invoke('get_asset_rigid_body_names', [asset]);
        return List.generate(
          len(result),
          (i) => result.getItem(PyInt(i)).asString(),
        );
      });
  @override
  GymArray get_asset_dof_properties(Asset asset) =>
      GymArrayPython(invoke('get_asset_dof_properties', [asset]));
  @override
  GymArray get_actor_dof_states(Env env, int actor, StateFlags flags) =>
      GymArrayPython(invoke('get_actor_dof_states', [env, actor, flags]));
  @override
  bool set_actor_dof_states(
    Env env,
    int actor,
    GymArray states,
    StateFlags flags,
  ) => ResourceScope.scope(
    () => invoke('set_actor_dof_states', [env, actor, states, flags]).asBool(),
  );
  @override
  bool set_actor_dof_properties(Env env, int actor, GymArray properties) =>
      ResourceScope.scope(
        () => invoke('set_actor_dof_properties', [
          env,
          actor,
          properties,
        ]).asBool(),
      );
  @override
  bool apply_actor_dof_efforts(Env env, int actor, List<double> efforts) =>
      ResourceScope.scope(() {
        final np = PyModule('numpy');
        final asarray = np.getAttr('asarray');
        final values = asarray.forward([efforts], kwargs: {'dtype': 'float32'});
        return invoke('apply_actor_dof_efforts', [env, actor, values]).asBool();
      });
  @override
  int find_actor_rigid_body_handle(Env env, int actor, String name) =>
      ResourceScope.scope(
        () =>
            invoke('find_actor_rigid_body_handle', [env, actor, name]).asInt(),
      );
  @override
  int get_actor_index(Env env, int actor, IndexDomain domain) =>
      ResourceScope.scope(
        () => invoke('get_actor_index', [env, actor, domain]).asInt(),
      );
  @override
  void prepare_sim(Sim sim) => invoke('prepare_sim', [sim]).dispose();
  @override
  Tensor acquire_actor_root_state_tensor(Sim sim) => ResourceScope.scope(() {
    final descriptor = invoke('acquire_actor_root_state_tensor', [sim]);
    final wrap = api.gymtorch.getAttr('wrap_tensor');
    return TensorPython(wrap.forward([descriptor]).detachToParentScope());
  });
  @override
  void refresh_actor_root_state_tensor(Sim sim) =>
      invoke('refresh_actor_root_state_tensor', [sim]).dispose();
  @override
  Tensor acquire_dof_state_tensor(Sim sim) => ResourceScope.scope(() {
    final descriptor = invoke('acquire_dof_state_tensor', [sim]);
    final wrap = api.gymtorch.getAttr('wrap_tensor');
    return TensorPython(wrap.forward([descriptor]).detachToParentScope());
  });
  @override
  void refresh_dof_state_tensor(Sim sim) =>
      invoke('refresh_dof_state_tensor', [sim]).dispose();
  @override
  Tensor acquire_rigid_body_state_tensor(Sim sim) => ResourceScope.scope(() {
    final descriptor = invoke('acquire_rigid_body_state_tensor', [sim]);
    final wrap = api.gymtorch.getAttr('wrap_tensor');
    return TensorPython(wrap.forward([descriptor]).detachToParentScope());
  });
  @override
  void refresh_rigid_body_state_tensor(Sim sim) =>
      invoke('refresh_rigid_body_state_tensor', [sim]).dispose();
  @override
  Tensor acquire_net_contact_force_tensor(Sim sim) => ResourceScope.scope(() {
    final descriptor = invoke('acquire_net_contact_force_tensor', [sim]);
    final wrap = api.gymtorch.getAttr('wrap_tensor');
    return TensorPython(wrap.forward([descriptor]).detachToParentScope());
  });
  @override
  void refresh_net_contact_force_tensor(Sim sim) =>
      invoke('refresh_net_contact_force_tensor', [sim]).dispose();
  @override
  bool set_actor_root_state_tensor(Sim sim, Tensor tensor) =>
      ResourceScope.scope(() {
        final unwrap = api.gymtorch.getAttr('unwrap_tensor');
        final descriptor = unwrap.forward([tensor]);
        return invoke('set_actor_root_state_tensor', [
          sim,
          descriptor,
        ]).asBool();
      });
  @override
  bool set_actor_root_state_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  ) => ResourceScope.scope(() {
    final unwrap = api.gymtorch.getAttr('unwrap_tensor');
    final descriptor = unwrap.forward([tensor]);
    final indices = unwrap.forward([actor_indices]);
    return invoke('set_actor_root_state_tensor_indexed', [
      sim,
      descriptor,
      indices,
      count,
    ]).asBool();
  });
  @override
  bool set_dof_state_tensor(Sim sim, Tensor tensor) => ResourceScope.scope(() {
    final unwrap = api.gymtorch.getAttr('unwrap_tensor');
    final descriptor = unwrap.forward([tensor]);
    return invoke('set_dof_state_tensor', [sim, descriptor]).asBool();
  });
  @override
  bool set_dof_state_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  ) => ResourceScope.scope(() {
    final unwrap = api.gymtorch.getAttr('unwrap_tensor');
    final descriptor = unwrap.forward([tensor]);
    final indices = unwrap.forward([actor_indices]);
    return invoke('set_dof_state_tensor_indexed', [
      sim,
      descriptor,
      indices,
      count,
    ]).asBool();
  });
  @override
  bool set_dof_actuation_force_tensor(Sim sim, Tensor tensor) =>
      ResourceScope.scope(() {
        final unwrap = api.gymtorch.getAttr('unwrap_tensor');
        final descriptor = unwrap.forward([tensor]);
        return invoke('set_dof_actuation_force_tensor', [
          sim,
          descriptor,
        ]).asBool();
      });
  @override
  bool set_dof_actuation_force_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  ) => ResourceScope.scope(() {
    final unwrap = api.gymtorch.getAttr('unwrap_tensor');
    final descriptor = unwrap.forward([tensor]);
    final indices = unwrap.forward([actor_indices]);
    return invoke('set_dof_actuation_force_tensor_indexed', [
      sim,
      descriptor,
      indices,
      count,
    ]).asBool();
  });
  @override
  bool set_dof_position_target_tensor(Sim sim, Tensor tensor) =>
      ResourceScope.scope(() {
        final unwrap = api.gymtorch.getAttr('unwrap_tensor');
        final descriptor = unwrap.forward([tensor]);
        return invoke('set_dof_position_target_tensor', [
          sim,
          descriptor,
        ]).asBool();
      });
  @override
  bool set_dof_position_target_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  ) => ResourceScope.scope(() {
    final unwrap = api.gymtorch.getAttr('unwrap_tensor');
    final descriptor = unwrap.forward([tensor]);
    final indices = unwrap.forward([actor_indices]);
    return invoke('set_dof_position_target_tensor_indexed', [
      sim,
      descriptor,
      indices,
      count,
    ]).asBool();
  });
  @override
  bool set_dof_velocity_target_tensor(Sim sim, Tensor tensor) =>
      ResourceScope.scope(() {
        final unwrap = api.gymtorch.getAttr('unwrap_tensor');
        final descriptor = unwrap.forward([tensor]);
        return invoke('set_dof_velocity_target_tensor', [
          sim,
          descriptor,
        ]).asBool();
      });
  @override
  bool set_dof_velocity_target_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  ) => ResourceScope.scope(() {
    final unwrap = api.gymtorch.getAttr('unwrap_tensor');
    final descriptor = unwrap.forward([tensor]);
    final indices = unwrap.forward([actor_indices]);
    return invoke('set_dof_velocity_target_tensor_indexed', [
      sim,
      descriptor,
      indices,
      count,
    ]).asBool();
  });

  PyObject invoke(String name, List<Object?> args) =>
      ResourceScope.returning(() {
        final method = handle.getAttr(name);
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
  ) => ResourceScope.scope(() {
    return invoke('create_actor', [
      env,
      asset,
      pose,
      name,
      collision_group,
      collision_filter,
    ]).asInt();
  });

  @override
  RigidBodyStates get_sim_rigid_body_states(Sim sim, StateFlags flags) =>
      RigidBodyStatesPython(invoke('get_sim_rigid_body_states', [sim, flags]));

  @override
  List<ActionEvent> query_viewer_action_events(Viewer viewer) =>
      ResourceScope.scope(() {
        final events = invoke('query_viewer_action_events', [viewer]);
        final count = len(events);
        return List.generate(count, (i) {
          final event = events.getItem(PyInt(i));
          return ActionEvent(
            event.getAttrString('action'),
            event.getAttrDouble('value'),
          );
        });
      });
  @override
  void destroy_viewer(covariant ViewerPython viewer) {
    invoke('destroy_viewer', [viewer]).dispose();
    viewer.release();
  }

  @override
  void destroy_sim(covariant SimPython sim) {
    invoke('destroy_sim', [sim]).dispose();
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
      invoke('add_ground', [sim, params]).dispose();
  @override
  void set_rigid_body_color(
    Env env,
    int actor,
    int body,
    MeshType mesh,
    Vector3 color,
  ) =>
      invoke('set_rigid_body_color', [env, actor, body, mesh, color]).dispose();
  @override
  void subscribe_viewer_keyboard_event(
    Viewer viewer,
    KeyboardInput key,
    String action,
  ) => invoke('subscribe_viewer_keyboard_event', [
    viewer,
    key,
    action,
  ]).dispose();
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
  ]).dispose();
  @override
  bool set_sim_rigid_body_states(
    Sim sim,
    RigidBodyStates states,
    StateFlags flags,
  ) => ResourceScope.scope(() {
    final v = invoke('set_sim_rigid_body_states', [sim, states, flags]);
    return v.asBool();
  });
  @override
  bool query_viewer_has_closed(Viewer viewer) => ResourceScope.scope(() {
    final v = invoke('query_viewer_has_closed', [viewer]);
    return v.asBool();
  });
  @override
  void simulate(Sim sim) => invoke('simulate', [sim]).dispose();
  @override
  void fetch_results(Sim sim, bool wait) =>
      invoke('fetch_results', [sim, wait]).dispose();
  @override
  void step_graphics(Sim sim) => invoke('step_graphics', [sim]).dispose();
  @override
  void draw_viewer(Viewer viewer, Sim sim, bool sync) =>
      invoke('draw_viewer', [viewer, sim, sync]).dispose();
  @override
  void sync_frame_time(Sim sim) => invoke('sync_frame_time', [sim]).dispose();
}
