import 'dart:typed_data';

import 'types.dart';

/// Session configuration shared by backend implementations.
class OrtSessionOptions {
  final int intraOpNumThreads;
  const OrtSessionOptions({this.intraOpNumThreads = 1});
}

/// Platform implementation of model loading and inference.
abstract interface class OrtBackend {
  Future<OrtSessionHandler> createSession(
    Uint8List model, {
    OrtSessionOptions options = const OrtSessionOptions(),
  });
}

/// Backend-owned session resources. Disposal must be idempotent.
abstract interface class OrtSessionHandler {
  List<String> get inputNames;
  List<String> get outputNames;
  Future<Map<String, OrtTensor>> run(Map<String, OrtTensor> feeds);
  Future<void> dispose();
}
