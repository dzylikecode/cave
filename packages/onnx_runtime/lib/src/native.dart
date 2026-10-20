import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'third_party/ort.g.dart' as g;
import 'types.dart';
import 'backend.dart';

/// CPU ONNX Runtime, bundled automatically by the xmake build hook.
class OrtRuntime {
  late final g.OrtApi _api;
  Pointer<g.OrtEnv> _env = nullptr;
  int _sessions = 0;
  bool _closed = false;
  OrtRuntime() {
    final base = g.OrtGetApiBase();
    final api = base.ref.GetApi.asFunction<Pointer<g.OrtApi> Function(int)>()(
      22,
    );
    if (api == nullptr) throw OrtException('ONNX Runtime API 22 is required');
    _api = api.ref;
    using((arena) {
      final out = arena<Pointer<g.OrtEnv>>();
      _check(_createEnv(2, 'dart'.toNativeUtf8(allocator: arena).cast(), out));
      _env = out.value;
    });
  }
  void _check(Pointer<g.OrtStatus> status) {
    if (status == nullptr) return;
    final message = _getErrorMessage(status).cast<Utf8>().toDartString();
    _releaseStatus(status);
    throw OrtException(message);
  }

  /// Releases the runtime after all sessions have been disposed.
  void dispose() {
    if (_closed) return;
    if (_sessions != 0) throw StateError('Dispose sessions before the runtime');
    _releaseEnv(_env);
    _closed = true;
  }

  late final _createEnv =
      _api.CreateEnv.asFunction<
        Pointer<g.OrtStatus> Function(
          int,
          Pointer<Char>,
          Pointer<Pointer<g.OrtEnv>>,
        )
      >();
  late final _getErrorMessage =
      _api.GetErrorMessage.asFunction<
        Pointer<Char> Function(Pointer<g.OrtStatus>)
      >();
  late final _createSessionOptions =
      _api.CreateSessionOptions.asFunction<
        Pointer<g.OrtStatus> Function(Pointer<Pointer<g.OrtSessionOptions>>)
      >();
  late final _setIntraOpNumThreads =
      _api.SetIntraOpNumThreads.asFunction<
        Pointer<g.OrtStatus> Function(Pointer<g.OrtSessionOptions>, int)
      >();
  late final _createSessionFromArray =
      _api.CreateSessionFromArray.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtEnv>,
          Pointer<Void>,
          int,
          Pointer<g.OrtSessionOptions>,
          Pointer<Pointer<g.OrtSession>>,
        )
      >();
  late final _getAllocatorWithDefaultOptions =
      _api.GetAllocatorWithDefaultOptions.asFunction<
        Pointer<g.OrtStatus> Function(Pointer<Pointer<g.OrtAllocator>>)
      >();
  late final _sessionGetInputCount =
      _api.SessionGetInputCount.asFunction<
        Pointer<g.OrtStatus> Function(Pointer<g.OrtSession>, Pointer<Size>)
      >();
  late final _sessionGetOutputCount =
      _api.SessionGetOutputCount.asFunction<
        Pointer<g.OrtStatus> Function(Pointer<g.OrtSession>, Pointer<Size>)
      >();
  late final _sessionGetInputName =
      _api.SessionGetInputName.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtSession>,
          int,
          Pointer<g.OrtAllocator>,
          Pointer<Pointer<Char>>,
        )
      >();
  late final _sessionGetOutputName =
      _api.SessionGetOutputName.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtSession>,
          int,
          Pointer<g.OrtAllocator>,
          Pointer<Pointer<Char>>,
        )
      >();
  late final _allocatorFree =
      _api.AllocatorFree.asFunction<
        Pointer<g.OrtStatus> Function(Pointer<g.OrtAllocator>, Pointer<Void>)
      >();
  late final _createCpuMemoryInfo =
      _api.CreateCpuMemoryInfo.asFunction<
        Pointer<g.OrtStatus> Function(
          int,
          int,
          Pointer<Pointer<g.OrtMemoryInfo>>,
        )
      >();
  late final _createTensorWithDataAsOrtValue =
      _api.CreateTensorWithDataAsOrtValue.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtMemoryInfo>,
          Pointer<Void>,
          int,
          Pointer<Int64>,
          int,
          int,
          Pointer<Pointer<g.OrtValue>>,
        )
      >();
  late final _run =
      _api.Run.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtSession>,
          Pointer<g.OrtRunOptions>,
          Pointer<Pointer<Char>>,
          Pointer<Pointer<g.OrtValue>>,
          int,
          Pointer<Pointer<Char>>,
          int,
          Pointer<Pointer<g.OrtValue>>,
        )
      >();
  late final _getTensorTypeAndShape =
      _api.GetTensorTypeAndShape.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtValue>,
          Pointer<Pointer<g.OrtTensorTypeAndShapeInfo>>,
        )
      >();
  late final _getTensorElementType =
      _api.GetTensorElementType.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtTensorTypeAndShapeInfo>,
          Pointer<UnsignedInt>,
        )
      >();
  late final _getDimensionsCount =
      _api.GetDimensionsCount.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtTensorTypeAndShapeInfo>,
          Pointer<Size>,
        )
      >();
  late final _getDimensions =
      _api.GetDimensions.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtTensorTypeAndShapeInfo>,
          Pointer<Int64>,
          int,
        )
      >();
  late final _getTensorMutableData =
      _api.GetTensorMutableData.asFunction<
        Pointer<g.OrtStatus> Function(
          Pointer<g.OrtValue>,
          Pointer<Pointer<Void>>,
        )
      >();
  late final _releaseEnv =
      _api.ReleaseEnv.asFunction<void Function(Pointer<g.OrtEnv>)>();
  late final _releaseStatus =
      _api.ReleaseStatus.asFunction<void Function(Pointer<g.OrtStatus>)>();
  late final _releaseSession =
      _api.ReleaseSession.asFunction<void Function(Pointer<g.OrtSession>)>();
  late final _releaseSessionOptions =
      _api.ReleaseSessionOptions.asFunction<
        void Function(Pointer<g.OrtSessionOptions>)
      >();
  late final _releaseMemoryInfo = _api
      .ReleaseMemoryInfo.asFunction<void Function(Pointer<g.OrtMemoryInfo>)>();
  late final _releaseValue =
      _api.ReleaseValue.asFunction<void Function(Pointer<g.OrtValue>)>();
  late final _releaseTensorTypeAndShapeInfo =
      _api.ReleaseTensorTypeAndShapeInfo.asFunction<
        void Function(Pointer<g.OrtTensorTypeAndShapeInfo>)
      >();
}

/// An ONNX model session. Dispose explicitly when finished.
class OrtSession {
  final OrtRuntime runtime;
  Pointer<g.OrtSession> _session = nullptr;
  bool _closed = false;
  late final List<String> inputNames;
  late final List<String> outputNames;
  OrtSession.fromFile(this.runtime, String path, {int threads = 1}) {
    if (runtime._closed) throw StateError('Runtime is disposed');
    if (threads < 1) throw ArgumentError.value(threads, 'threads');
    _initialize(File(path).readAsBytesSync(), threads);
  }

  OrtSession.fromBytes(this.runtime, Uint8List bytes, {int threads = 1}) {
    if (runtime._closed) throw StateError('Runtime is disposed');
    if (threads < 1) throw ArgumentError.value(threads, 'threads');
    _initialize(bytes, threads);
  }

  void _initialize(Uint8List bytes, int threads) {
    using((arena) {
      final options = arena<Pointer<g.OrtSessionOptions>>();
      runtime._check(runtime._createSessionOptions(options));
      try {
        runtime._check(runtime._setIntraOpNumThreads(options.value, threads));
        final buffer = arena<Uint8>(bytes.length)
          ..asTypedList(bytes.length).setAll(0, bytes);
        final out = arena<Pointer<g.OrtSession>>();
        runtime._check(
          runtime._createSessionFromArray(
            runtime._env,
            buffer.cast(),
            bytes.length,
            options.value,
            out,
          ),
        );
        _session = out.value;
      } finally {
        runtime._releaseSessionOptions(options.value);
      }
    });
    try {
      inputNames = _names(true);
      outputNames = _names(false);
    } catch (_) {
      runtime._releaseSession(_session);
      rethrow;
    }
    runtime._sessions++;
  }

  List<String> _names(bool input) => using((arena) {
    final allocator = arena<Pointer<g.OrtAllocator>>();
    runtime._check(runtime._getAllocatorWithDefaultOptions(allocator));
    final count = arena<Size>();
    runtime._check(
      (input ? runtime._sessionGetInputCount : runtime._sessionGetOutputCount)(
        _session,
        count,
      ),
    );
    return List.unmodifiable(
      List.generate(count.value, (i) {
        final name = arena<Pointer<Char>>();
        runtime._check(
          (input
              ? runtime._sessionGetInputName
              : runtime._sessionGetOutputName)(
            _session,
            i,
            allocator.value,
            name,
          ),
        );
        try {
          return name.value.cast<Utf8>().toDartString();
        } finally {
          runtime._check(
            runtime._allocatorFree(allocator.value, name.value.cast()),
          );
        }
      }),
    );
  });

  /// Runs all outputs synchronously. Input and output tensors are float32.
  Map<String, OrtTensor> run(Map<String, OrtTensor> inputs) {
    if (_closed) throw StateError('Session is disposed');
    if (inputs.length != inputNames.length ||
        inputNames.any((name) => !inputs.containsKey(name))) {
      throw ArgumentError('Expected inputs: $inputNames');
    }
    return using((arena) {
      final memory = arena<Pointer<g.OrtMemoryInfo>>();
      runtime._check(runtime._createCpuMemoryInfo(1, 0, memory));
      final inValues = arena<Pointer<g.OrtValue>>(inputNames.length);
      final outValues = arena<Pointer<g.OrtValue>>(outputNames.length);
      try {
        final inNames = arena<Pointer<Char>>(inputNames.length);
        final outNames = arena<Pointer<Char>>(outputNames.length);
        for (var i = 0; i < inputNames.length; i++) {
          inNames[i] = inputNames[i].toNativeUtf8(allocator: arena).cast();
          final tensor = inputs[inputNames[i]]!;
          final data = arena<Float>(
            tensor.data.isEmpty ? 1 : tensor.data.length,
          );
          data.asTypedList(tensor.data.length).setAll(0, tensor.data);
          final shape = arena<Int64>(
            tensor.shape.isEmpty ? 1 : tensor.shape.length,
          );
          shape.asTypedList(tensor.shape.length).setAll(0, tensor.shape);
          runtime._check(
            runtime._createTensorWithDataAsOrtValue(
              memory.value,
              data.cast(),
              tensor.data.length * 4,
              shape,
              tensor.shape.length,
              1,
              inValues + i,
            ),
          );
        }
        for (var i = 0; i < outputNames.length; i++) {
          outNames[i] = outputNames[i].toNativeUtf8(allocator: arena).cast();
        }
        runtime._check(
          runtime._run(
            _session,
            nullptr,
            inNames,
            inValues,
            inputNames.length,
            outNames,
            outputNames.length,
            outValues,
          ),
        );
        return {
          for (var i = 0; i < outputNames.length; i++)
            outputNames[i]: _copyTensor(outValues[i]),
        };
      } finally {
        for (var i = 0; i < inputNames.length; i++) {
          if (inValues[i] != nullptr) runtime._releaseValue(inValues[i]);
        }
        for (var i = 0; i < outputNames.length; i++) {
          if (outValues[i] != nullptr) runtime._releaseValue(outValues[i]);
        }
        runtime._releaseMemoryInfo(memory.value);
      }
    });
  }

  OrtTensor _copyTensor(Pointer<g.OrtValue> value) => using((arena) {
    final info = arena<Pointer<g.OrtTensorTypeAndShapeInfo>>();
    runtime._check(runtime._getTensorTypeAndShape(value, info));
    try {
      final type = arena<UnsignedInt>();
      runtime._check(runtime._getTensorElementType(info.value, type));
      if (type.value != 1) {
        throw UnsupportedError('Only float32 outputs are supported');
      }
      final rank = arena<Size>();
      runtime._check(runtime._getDimensionsCount(info.value, rank));
      final dims = arena<Int64>(rank.value == 0 ? 1 : rank.value);
      runtime._check(runtime._getDimensions(info.value, dims, rank.value));
      final shape = dims.asTypedList(rank.value).toList();
      final data = arena<Pointer<Void>>();
      runtime._check(runtime._getTensorMutableData(value, data));
      final count = shape.fold(1, (a, b) => a * b);
      return OrtTensor(
        shape,
        count == 0
            ? Float32List(0)
            : data.value.cast<Float>().asTypedList(count),
      );
    } finally {
      runtime._releaseTensorTypeAndShapeInfo(info.value);
    }
  });
  void dispose() {
    if (_closed) return;
    runtime._releaseSession(_session);
    runtime._sessions--;
    _closed = true;
  }
}

/// Native C API backend. Owns a runtime when none is supplied.
class OrtNativeBackend implements OrtBackend {
  final OrtRuntime? runtime;
  OrtNativeBackend({this.runtime});

  @override
  Future<OrtSessionHandler> createSession(
    Uint8List model, {
    OrtSessionOptions options = const OrtSessionOptions(),
  }) async {
    final activeRuntime = runtime ?? OrtRuntime();
    try {
      final session = OrtSession.fromBytes(
        activeRuntime,
        model,
        threads: options.intraOpNumThreads,
      );
      return _NativeSessionHandler(session, runtime == null);
    } catch (_) {
      if (runtime == null) activeRuntime.dispose();
      rethrow;
    }
  }
}

class _NativeSessionHandler implements OrtSessionHandler {
  final OrtSession session;
  final bool ownsRuntime;
  _NativeSessionHandler(this.session, this.ownsRuntime);

  @override
  List<String> get inputNames => session.inputNames;
  @override
  List<String> get outputNames => session.outputNames;

  @override
  Future<Map<String, OrtTensor>> run(Map<String, OrtTensor> feeds) async =>
      session.run(feeds);

  @override
  Future<void> dispose() async {
    session.dispose();
    if (ownsRuntime) session.runtime.dispose();
  }
}
