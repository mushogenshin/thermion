import 'dart:io';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {

  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    // thermion_dart's hook skips metadata when not building code assets
    // (e.g. web builds); there's no native CMake step to feed in that case.
    // Matches code_assets's buildCodeAssets getter without importing that
    // package just for a single gate.
    if (!input.config.buildAssetTypes.contains('code_assets/code')) {
      return;
    }

    // Defensive: if thermion_dart's hook returned without publishing
    // includeDirs metadata (e.g. kineograph-desktop-only's `OS.linux`
    // early return in thermion_dart/hook/build.dart), there's nothing
    // to emit here either. The plugin isn't linked on Linux anyway —
    // thermion_flutter's `flutter.plugin.platforms` strips Linux on
    // this fork branch.
    //
    // The outer `input.metadata["thermion_dart"]` returns an empty
    // map (not null) when thermion_dart skipped, so we have to gate
    // on the inner key being present rather than the outer lookup.
    final thermionDartMetadata = input.metadata["thermion_dart"];
    final includeDirsRaw = thermionDartMetadata?["includeDirs"];
    if (includeDirsRaw == null) {
      return;
    }

    final includeDirs = (includeDirsRaw as List).cast<String>();
    final cmakeSafePath = includeDirs.map((dir) => dir.replaceAll('\\', '/')).map((dir) => '"$dir"').join(" ");
    final cmakeContent = 'set(DART_PKG_HEADERS $cmakeSafePath)';

    final outfile = File.fromUri(input.packageRoot.resolve('.dart_tool/generated_headers.cmake'));
    if(!outfile.parent.existsSync()) {
      outfile.parent.createSync();
    }
    await outfile.writeAsString(cmakeContent);

  });
}