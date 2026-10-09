// ignore_for_file: non_constant_identifier_names
import 'package:meta/meta.dart';
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

enum KeyboardInput { r }

/// Select which rigid-body state components to read or restore.
enum StateFlags { none, pos, vel, all }

/// Dart configuration values are copied into Python when passed to Gym.
/// Null fields preserve the SDK defaults.
class SimParams {
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
  int? num_threads;
  bool? use_gpu;
}

class FlexParams {
  double? shape_collision_margin;
  int? num_outer_iterations;
  int? num_inner_iterations;
}

class PlaneParams {}

class CameraProperties {}

class AssetOptions {}

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
