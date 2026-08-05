import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/python.g.dart',
        linkMode: LookupInProcess(),
      ),
    );
  });
}
