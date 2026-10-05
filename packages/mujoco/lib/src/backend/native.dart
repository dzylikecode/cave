// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;

import '../mujoco_base.dart';
import 'native.g.dart' as g;

final class const NativeApi() implements BaseApi {
  @override
  String get version => g.mj_versionString().cast<ffi.Utf8>().toDartString();

  @override
  MjData MjData_new(covariant MjModelNative model) =>
      MjDataNative(g.mj_makeData(model.ptr), model);

  @override
  MjModelNative MjModel_from_xml_string(String xml) {
    final vfs = MjVfsNative();
    try {
      const filename = 'model_.xml';
      vfs.addBuffer(filename, .fromList(utf8.encode(xml)));
      return _loadXml(filename, vfs: vfs);
    } finally {
      vfs.dispose();
    }
  }

  @override
  MjModelNative MjModel_from_xml_path(String path) => _loadXml(path);

  /// Loads XML using [vfs]; null uses the system file system.
  MjModelNative _loadXml(String filename, {MjVfsNative? vfs}) =>
      ffi.using((arena) {
        const errorSize = 1024;
        final error = arena<Char>(errorSize);
        final model = g.mj_loadXML(
          filename.toNativeUtf8(allocator: arena).cast<Char>(),
          vfs?.ptr ?? nullptr,
          error,
          errorSize,
        );
        if (model == nullptr) {
          throw FormatException(error.cast<ffi.Utf8>().toDartString());
        }
        return MjModelNative(model);
      });

  @override
  void mj_forward(covariant MjModelNative model, covariant MjDataNative data) =>
      g.mj_forward(model.ptr, data.ptr);

  @override
  void mj_step(covariant MjModelNative model, covariant MjDataNative data) =>
      g.mj_step(model.ptr, data.ptr);

  @override
  void mj_resetData(
    covariant MjModelNative model,
    covariant MjDataNative data,
  ) => g.mj_resetData(model.ptr, data.ptr);
}

/// Owns a MuJoCo virtual file system and its in-memory files.
class MjVfsNative._(final Pointer<g.mjVFS> ptr) {
  this {
    g.mj_defaultVFS(ptr);
  }
  factory() => ._(ffi.calloc<g.mjVFS>());

  /// Adds a file; MuJoCo copies [bytes] into the VFS.
  void addBuffer(String filename, Uint8List bytes) => ffi.using((arena) {
    final buffer = arena<Uint8>(bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    final result = g.mj_addBufferVFS(
      ptr,
      filename.toNativeUtf8(allocator: arena).cast<Char>(),
      buffer.cast<Void>(),
      bytes.length,
    );
    if (result != 0) {
      throw StateError(
        'Failed to add "$filename" to MuJoCo VFS (code $result).',
      );
    }
  });

  void dispose() {
    // 不会释放结构体，只会释放相关文件
    g.mj_deleteVFS(ptr);
    ffi.calloc.free(ptr);
  }
}

class MjModelNative(final Pointer<g.mjModel> ptr) implements MjModel {
  @override
  int get nq => ptr.ref.nq;

  @override
  int get nv => ptr.ref.nv;

  @override
  int get nu => ptr.ref.nu;

  @override
  int get na => ptr.ref.na;

  @override
  int get nsensor => ptr.ref.nsensor;

  @override
  int get nsensordata => ptr.ref.nsensordata;

  @override
  MjModelSensorViewsNative sensor(String name) {
    final id = ffi.using(
      (arena) => g.mj_name2id(
        ptr,
        g.mjtObj.mjOBJ_SENSOR.value,
        name.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    );
    return sensorById(id);
  }

  @override
  MjModelSensorViewsNative sensorById(int id) {
    RangeError.checkValidIndex(id, this, 'id', nsensor);
    return MjModelSensorViewsNative(this, id);
  }

  @override
  void dispose() => g.mj_deleteModel(ptr);
}

class MjDataNative(
  final Pointer<g.mjData> ptr,
  @override final MjModelNative model,
) implements MjData {
  @override
  double get time => ptr.ref.time;

  @override
  final MjDoubleListViewNative qpos = .new(ptr.ref.qpos, model.nq);

  @override
  final MjDoubleListViewNative qvel = .new(ptr.ref.qvel, model.nv);

  @override
  final MjDoubleListViewNative qacc = .new(ptr.ref.qacc, model.nv);

  @override
  final MjDoubleListViewNative act = .new(ptr.ref.act, model.na);

  @override
  final MjDoubleListViewNative ctrl = .new(ptr.ref.ctrl, model.nu);

  @override
  final MjDoubleListViewNative sensordata = .new(
    ptr.ref.sensordata,
    model.nsensordata,
  );

  @override
  MjDataSensorViewsNative sensor(String name) =>
      sensorById(model.sensor(name).id);

  @override
  MjDataSensorViewsNative sensorById(int id) =>
      MjDataSensorViewsNative(this, model.sensorById(id));

  @override
  void dispose() => g.mj_deleteData(ptr);
}

class MjDoubleListViewNative(final Pointer<Double> ptr, final int _length)
    implements MjDoubleListView {
  @override
  int get length => _length;

  @override
  double operator [](int index) => ptr[index];

  @override
  void operator []=(int index, double value) => ptr[index] = value;

  @override
  List<double> toList() => ptr.asTypedList(length).toList();
}

class MjModelSensorViewsNative(
  final MjModelNative model,
  @override final int id,
) implements MjModelSensorViews {
  @override
  String get name {
    final name = g.mj_id2name(model.ptr, g.mjtObj.mjOBJ_SENSOR.value, id);
    return name == nullptr ? '' : name.cast<ffi.Utf8>().toDartString();
  }

  @override
  int get type => model.ptr.ref.sensor_type[id];

  @override
  int get dim => model.ptr.ref.sensor_dim[id];

  @override
  int get adr => model.ptr.ref.sensor_adr[id];
}

class MjDataSensorViewsNative(
  final MjDataNative owner,
  final MjModelSensorViewsNative sensor,
) implements MjDataSensorViews {
  @override
  int get id => sensor.id;

  @override
  String get name => sensor.name;

  @override
  final MjDoubleListViewNative data = .new(
    owner.ptr.ref.sensordata + sensor.adr,
    sensor.dim,
  );
}
