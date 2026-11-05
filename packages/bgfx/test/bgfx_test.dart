// Copyright (c) 2026 dzylikecode. Licensed under the MIT License.
import 'package:test/test.dart';

import '../example/native_smoke.dart' as smoke;

void main() {
  // 真实调用初始化、提交与关闭，覆盖绑定 ABI 和原生库加载。
  test('Noop renderer initializes and advances frames', smoke.main);
}
