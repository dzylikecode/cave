// ignore_for_file: non_constant_identifier_names, constant_identifier_names
import 'package:meta/meta.dart';

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

const SIM_PHYSX = SimType.physx;
const SIM_FLEX = SimType.flex;

enum MeshType { visualAndCollision }

const MESH_VISUAL_AND_COLLISION = MeshType.visualAndCollision;

enum KeyboardInput { r }

const KEY_R = KeyboardInput.r;
const STATE_ALL = 3;

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

class Vec3 {
  double x, y, z;
  Vec3(this.x, this.y, this.z);
}

class Quat {
  double x, y, z, w;
  Quat(this.x, this.y, this.z, this.w);
}

class Transform {
  Vec3 p = Vec3(0, 0, 0);
  Quat r = Quat(0, 0, 0, 1);
}

/// Owned by Gym; release with destroy_sim. Its assets and environments then expire.
abstract interface class Sim {}

abstract interface class Env {}

abstract interface class Asset {}

/// Release with destroy_viewer before destroying its simulation.
abstract interface class Viewer {}

/// Opaque NumPy state array. copy() creates an independent reset snapshot.
/// Release every returned array with dispose().
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
  Env create_env(Sim sim, Vec3 lower, Vec3 upper, int num_per_row);
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
    Vec3 color,
  );
  void subscribe_viewer_keyboard_event(
    Viewer viewer,
    KeyboardInput key,
    String action,
  );
  void viewer_camera_look_at(
    Viewer viewer,
    Env? env,
    Vec3 position,
    Vec3 target,
  );
  RigidBodyStates get_sim_rigid_body_states(Sim sim, int flags);
  bool set_sim_rigid_body_states(Sim sim, RigidBodyStates states, int flags);
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
