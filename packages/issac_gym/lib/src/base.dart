// ignore_for_file: non_constant_identifier_names
import 'package:meta/meta.dart';
import 'package:torch_dart/torch_dart.dart' show Tensor;
import 'package:vector_math/vector_math.dart' show Vector3, Quaternion;

import 'backend/python.dart';

@internal
final pythonApi = PythonApi();
@internal
BaseApi get api => pythonApi;

Gym acquire_gym() => api.acquire_gym();

@internal
abstract interface class BaseApi {
  Gym acquire_gym();
}

enum SimType { physx, flex }

enum MeshType { visualAndCollision }

enum KeyboardInput { r, escape }

enum UpAxis { y, z }

enum DofDriveMode { none, pos, vel, effort }

enum IndexDomain { actor, env, sim }

/// Select which rigid-body state components to read or restore.
enum StateFlags { none, pos, vel, all }

/// Dart configuration values are copied into Python when passed to Gym.
/// Null fields preserve the SDK defaults.
class SimParams {
  UpAxis? up_axis;
  Vector3? gravity;
  double? dt;
  int? substeps;
  bool? use_gpu_pipeline;
  final physx = PhysXParams();
  final flex = FlexParams();
}

class PhysXParams {
  int? solver_type;
  int? num_position_iterations;
  int? num_velocity_iterations;
  double? contact_offset;
  double? rest_offset;
  double? bounce_threshold_velocity;
  double? max_depenetration_velocity;
  int? max_gpu_contact_pairs;
  double? default_buffer_size_multiplier;
  int? num_threads;
  bool? use_gpu;
}

class FlexParams {
  double? shape_collision_margin;
  int? num_outer_iterations;
  int? num_inner_iterations;
}

class PlaneParams {
  Vector3? normal;
  double? static_friction;
  double? dynamic_friction;
  double? restitution;
}

class CameraProperties {}

class AssetOptions {
  bool? fix_base_link;
  bool? collapse_fixed_joints;
  bool? disable_gravity;
  bool? flip_visual_attachments;
  bool? replace_cylinder_with_capsule;
  double? density;
  double? angular_damping;
  double? linear_damping;
  double? max_angular_velocity;
  double? max_linear_velocity;
  double? armature;
  double? thickness;
  DofDriveMode? default_dof_drive_mode;
}

/// Owned NumPy structured array. Field reads copy values to Dart.
/// Dispose each array, including copies, once after use.
abstract interface class GymArray {
  int get length;
  List<double> field(String name);
  void setField(String name, List<num> values);
  GymArray copy();
  void dispose();
}

class Transform {
  Vector3 p = Vector3.zero();
  Quaternion r = Quaternion.identity();
}

/// Release once with destroy_sim, after destroying its viewers.
/// Its assets and environments then expire; callers manage lifetime and pairing.
abstract interface class Sim {}

abstract interface class Env {}

abstract interface class Asset {}

/// Release once with destroy_viewer before destroying its simulation.
abstract interface class Viewer {}

/// Opaque NumPy state array. copy() creates an independent reset snapshot.
/// Release every returned array once with dispose(); do not access it afterward.
abstract interface class RigidBodyStates {
  int get length;
  RigidBodyStates copy();
  void dispose();
}

class ActionEvent {
  final String action;
  final double value;
  const ActionEvent(this.action, this.value);
}

abstract interface class Gym {
  /// Tensor acquisitions alias simulation memory; dispose wrappers before destroy_sim.
  /// Call prepare_sim after creating actors, refresh before reads, and keep setter
  /// tensors alive through simulate/fetch_results. Indexed IDs are contiguous int32
  /// actor indices in the simulation domain, on the simulation's device.
  int get_asset_dof_count(Asset asset);
  int get_asset_rigid_body_count(Asset asset);
  int get_asset_rigid_shape_count(Asset asset);
  List<String> get_asset_dof_names(Asset asset);
  List<String> get_asset_rigid_body_names(Asset asset);
  GymArray get_asset_dof_properties(Asset asset);
  GymArray get_actor_dof_states(Env env, int actor, StateFlags flags);
  bool set_actor_dof_states(
    Env env,
    int actor,
    GymArray states,
    StateFlags flags,
  );
  bool set_actor_dof_properties(Env env, int actor, GymArray properties);
  bool apply_actor_dof_efforts(Env env, int actor, List<double> efforts);

  /// Sets each collision shape's friction, preserving its other properties.
  void set_actor_friction(Env env, int actor, double friction);
  List<double> get_actor_rigid_body_masses(Env env, int actor);
  void set_actor_rigid_body_masses(Env env, int actor, List<double> masses);
  int find_actor_rigid_body_handle(Env env, int actor, String name);
  int get_actor_index(Env env, int actor, IndexDomain domain);
  void prepare_sim(Sim sim);
  Tensor acquire_actor_root_state_tensor(Sim sim);
  void refresh_actor_root_state_tensor(Sim sim);
  Tensor acquire_dof_state_tensor(Sim sim);
  void refresh_dof_state_tensor(Sim sim);
  Tensor acquire_rigid_body_state_tensor(Sim sim);
  void refresh_rigid_body_state_tensor(Sim sim);
  Tensor acquire_net_contact_force_tensor(Sim sim);
  void refresh_net_contact_force_tensor(Sim sim);
  bool set_actor_root_state_tensor(Sim sim, Tensor tensor);
  bool set_actor_root_state_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  );
  bool set_dof_state_tensor(Sim sim, Tensor tensor);
  bool set_dof_state_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  );
  bool set_dof_actuation_force_tensor(Sim sim, Tensor tensor);
  bool set_dof_actuation_force_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  );
  bool set_dof_position_target_tensor(Sim sim, Tensor tensor);
  bool set_dof_position_target_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  );
  bool set_dof_velocity_target_tensor(Sim sim, Tensor tensor);
  bool set_dof_velocity_target_tensor_indexed(
    Sim sim,
    Tensor tensor,
    Tensor actor_indices,
    int count,
  );

  Sim create_sim(
    int compute_device_id,
    int graphics_device_id,
    SimType type,
    SimParams params,
  );
  void add_ground(Sim sim, PlaneParams params);
  Viewer create_viewer(Sim sim, CameraProperties properties);
  Asset load_asset(Sim sim, String root, String file, AssetOptions options);
  Env create_env(Sim sim, Vector3 lower, Vector3 upper, int num_per_row);
  int create_actor(
    Env env,
    Asset asset,
    Transform pose,
    String? name,
    int collision_group,
    int collision_filter,
  );
  void set_rigid_body_color(
    Env env,
    int actor,
    int body,
    MeshType mesh,
    Vector3 color,
  );
  void subscribe_viewer_keyboard_event(
    Viewer viewer,
    KeyboardInput key,
    String action,
  );
  void viewer_camera_look_at(
    Viewer viewer,
    Env? env,
    Vector3 position,
    Vector3 target,
  );
  RigidBodyStates get_sim_rigid_body_states(Sim sim, StateFlags flags);
  bool set_sim_rigid_body_states(
    Sim sim,
    RigidBodyStates states,
    StateFlags flags,
  );
  bool query_viewer_has_closed(Viewer viewer);
  List<ActionEvent> query_viewer_action_events(Viewer viewer);
  void simulate(Sim sim);
  void fetch_results(Sim sim, bool wait);
  void step_graphics(Sim sim);
  void draw_viewer(Viewer viewer, Sim sim, bool sync);
  void sync_frame_time(Sim sim);
  void destroy_viewer(Viewer viewer);
  void destroy_sim(Sim sim);

  /// Release the Python wrapper after destroying its simulations and viewers.
  void dispose();
}
