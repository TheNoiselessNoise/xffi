import 'dart:io';
import 'package:xffi_gen/xffi_gen.dart';
import 'writer.dart';

Future<XContext> runFfigenFrontend({
  required XGeneratorConfig config,
  required Uri headerPath,
  required Uri workDir,
}) async {
  final rawOutputPath = workDir.resolve('_raw_ffigen_output.dart');
  final yamlConfigPath = workDir.resolve('_ffigen_config.yaml');

  await Directory(workDir.toFilePath()).create(recursive: true);
  await File(yamlConfigPath.toFilePath()).writeAsString(_buildYamlConfig(
    headerPath: headerPath.toFilePath(),
    outputPath: rawOutputPath.toFilePath(),
  ));

  final context = XContext(config, rawOutputPath.toFilePath());

  context.c2Dart = .new(
    context: context,
    c2DartWriter: MyC2DartWriter.new,
    compilerOptions: [
      '-I/usr/include',
      '-I/usr/lib/clang/21/include',
    ],
    entryPoints: [
      headerPath,
    ],
    outputDartFile: rawOutputPath,
    formatDartFile: true,
    importFFIAsAlias: false,
    writerOptions: .new(
      libraryName: 'Raylib',
    ),
  );

  context.c2Dart.collect();

  return context;
}

String _buildYamlConfig({required String headerPath, required String outputPath}) {
  return '''
name: RawFrontend
description: Throwaway first-pass bindings; only read by our own collector.
ffi-native:
output: '$outputPath'
headers:
  entry-points:
    - '$headerPath'
comments: false
''';
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run bin/generate.dart <header.h>');
    exitCode = 1;
    return;
  }

  final config = XGeneratorConfig(
    headerPath: args[0],
    workDir: '.dart_tool/gen_work',
    outDir: 'lib/src/generated',
    defaultStructMode: .struct,
    structModes: const {
      '__va_list_tag': .skip,
      'Vector2': .value,
    },
    fieldOverrides: const {
      'AudioStream.buffer': XOpaque(),
      'AudioStream.processor': XOpaque(),
      
      'Music.ctxData': XOpaque(),
      
      'Wave.data': XOpaque(),
      
      'AutomationEventList.events': XLengthField('count'),
      
      'FilePathList.paths': XLengthField('count'),
      
      'Shader.locs': XLengthField('shaderLocsCount', isExternal: true),

      'BoneInfo.name': XString(),
      
      'Font.recs': XLengthField('glyphCount'),
      'Font.glyphs': XLengthField('glyphCount'),
      
      'Image.data': XOpaque(asView: .Uint8List),

      'Material.maps': XLengthField('RaylibConstants.MAX_MATERIAL_MAPS', isExternal: true),
      'Material.params': XFixedLength(4),

      'Mesh.vertices': XLengthField('verticesCount', isExternal: true),
      'Mesh.texcoords': XLengthField('texcoordsCount', isExternal: true),
      'Mesh.texcoords2': XLengthField('texcoords2Count', isExternal: true),
      'Mesh.normals': XLengthField('normalsCount', isExternal: true),
      'Mesh.tangents': XLengthField('tangentsCount', isExternal: true),
      'Mesh.colors': XLengthField('colorsCount', isExternal: true),
      'Mesh.indices': XLengthField('indicesCount', isExternal: true),
      'Mesh.boneIndices': XLengthField('boneIndicesCount', isExternal: true),
      'Mesh.boneWeights': XLengthField('boneWeightsCount', isExternal: true),
      'Mesh.animVertices': XLengthField('animVerticesCount', isExternal: true),
      'Mesh.animNormals': XLengthField('animNormalsCount', isExternal: true),
      'Mesh.vboId': XLengthField('vboIdCount', isExternal: true),

      'Model.meshes': XLengthField('meshCount'),
      'Model.materials': XLengthField('materialCount'),
      'Model.meshMaterial': XLengthField('materialCount'),
      'Model.currentPose': XLengthField('skeleton.boneCount', isExternal: true),
      'Model.boneMatrices': XLengthField('skeleton.boneCount', isExternal: true),

      'ModelAnimation.keyframePoses': XLengthField('keyframeCount'),

      'ModelSkeleton.bones': XLengthField('boneCount'),
      'ModelSkeleton.bindPose': XLengthField('boneCount'),
    },
  );


  // parse and collect
  final context = await runFfigenFrontend(
    config: config,
    headerPath: .file(config.headerPath),
    workDir: .file(config.workDir),
  );

  // classify struct fields in place
  classifyStructs(context, config);

  await Directory(config.outDir).create(recursive: true);
  final outFile = File('${config.outDir}/generated_bindings.dart');
  await outFile.writeAsString(context.c2Dart.writer.writeContent());
  stdout.writeln('Wrote ${outFile.path}');
}