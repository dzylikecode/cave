// import 'dart:io';

// import 'package:py_embed/py_embed.dart';
// import 'package:torch_dart/torch_dart.dart' as torch;

// void main() {
//   final modelPath = File.fromUri(
//     Platform.script.resolve('../assets/models/lite_yuhan1.pt'),
//   ).path;

//   try {
//     final model = torch.jit.load(modelPath, map_location: .new(.cpu))..eval();
//     final input = torch.zeros(
//       [1, 21 * 56],
//       dtype: .float32,
//       device: .new(.cpu),
//     );
//     final output = torch.inference_mode(() => model(input));
//     print('PyTorch ${torch.Torch.version}');
//     print('model: $modelPath');
//     print('input shape: ${input.shape}');
//     print('output shape: ${output.shape}');
//     print('actions: ${output.toList()}');
//   } finally {
//     pyRuntime.dispose();
//   }
// }
