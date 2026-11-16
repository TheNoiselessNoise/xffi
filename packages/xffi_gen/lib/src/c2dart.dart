part of '../xffi_gen.dart';

final class C2DartWriteOptions {
  final String libraryName;

  C2DartWriteOptions({
    required this.libraryName,
  });

  factory C2DartWriteOptions.empty() => C2DartWriteOptions(
    libraryName: 'UnknownLibrary',
  );
}

abstract class C2DartWriter extends Writable {
  final XContext context;

  C2DartVisitor get visitor => context.c2Dart.visitor;
  Library get ffiLibrary => context.c2Dart.ffiLibrary;
  Context get ffiContext => ffiLibrary.context;

  C2DartWriter(this.context);

  void _visit({bool debug = false}) => doVisit(ffiContext, visitor, ffiLibrary.bindings, debug: debug);
  
  // NOTE: it seems that stringify into FFI binding
  //       is not so easy, so let's keep ffigen's way for now
  String getNodeDartCode(Binding node) => node.toBindingString(ffiLibrary.writer).string;

  String writeBindings(List<Binding> bindings)
    => writeIsolated(() => write(bindings.map(getNodeDartCode).join('\n')));

  String writeContent();
}

final class C2DartVisitor extends Visitation {
  late Context context;

  Map<String, Struct> structs = {};
  Map<String, XStructDecl> classifiedStructs = {};

  Map<String, Typealias> typeAliases = {};
  Map<String, EnumClass> enums = {};
  Map<String, Func> funcs = {};
  Map<String, MacroConstant> macroConstants = {};
  Map<String, Constant> constants = {};

  @override
  void visitConstant(Constant node) {
    if (node.name.startsWith('__')) return;
    node.isIncluded = true;
    constants[node.name] = node;
  }

  @override
  void visitMacroConstant(MacroConstant node) {
    if (node.name.startsWith('__')) return;
    node.isIncluded = true;
    macroConstants[node.name] = node;
  }

  @override
  void visitStruct(Struct node) {
    if (!node.name.startsWith('__') || node.name == '__va_list_tag') {
      node.isIncluded = true;
      structs[node.name] = node;
    }
  }

  @override
  void visitEnumClass(EnumClass node) {
    if (node.name.startsWith('__')) return;
    node.isIncluded = true;
    enums[node.name] = node;
  }

  @override
  void visitFunc(Func node) {
    if (node.name.startsWith('__')) return;
    node.isIncluded = true;
    funcs[node.name] = node;
  }

  @override
  void visitTypealias(Typealias node) {
    if (node.name.startsWith('__')) return;
    if (node.name.contains('__')) return;
    final cType = node.type.getCType(context).trim();
    if (cType.startsWith('__')) return;
    if (cType.contains('__')) return;
    node.isIncluded = .always;
    typeAliases[node.name] = node;
  }
}

typedef C2DartWriterConstructor = C2DartWriter Function(XContext context);

final class C2Dart {
  final XContext context;
  final C2DartWriterConstructor c2DartWriter;
  final bool importFFIAsAlias;
  final Uri outputDartFile;
  final List<Uri> entryPoints;
  final List<String> compilerOptions;
  final C2DartWriteOptions writerOptions;
  final bool formatDartFile;

  C2Dart({
    required this.context,
    required this.c2DartWriter,
    this.importFFIAsAlias = false,
    required this.outputDartFile,
    required this.entryPoints,
    required this.compilerOptions,
    C2DartWriteOptions? writerOptions,
    this.formatDartFile = true,
  }) :
    writerOptions = writerOptions ?? .empty()
  { _init(); }

  late final FfiGenerator generator;
  late final Context ffiContext;
  late final Library ffiLibrary;
  late final C2DartVisitor visitor;
  late final C2DartWriter writer;
  Logger get logger => context.c2Dart.ffiContext.logger;

  void _init() {
    context.c2Dart = this;
    
    generator = FfiGenerator(
      input: Input(
        entryPoints: entryPoints,
        compilerOptions: compilerOptions,
      ),
      output: Output(
        dart: DartOutput(path: outputDartFile),
        format: formatDartFile,

        // NOTE: keep DynamicLibraryBindings
        style: DynamicLibraryBindings(
          wrapperName: writerOptions.libraryName,
        ),
      ),
      visitors: [
        Visitor(
          struct: (node) => node.isIncluded = true,
          enumClass: (node) => node.isIncluded = true,
          func: (node) => node.isIncluded = true,
          global: (node) => node.isIncluded = true,
          macroConstant: (node) => node.isIncluded = true,
          typealias: (node) => node.isIncluded = .always,
          unnamedEnumConstant: (node) => node.isIncluded = true,
          union: (node) => node.isIncluded = true,
          cppClass: (node) => node.isIncluded = true,
          cppMethod: (node) => node.isIncluded = true,
          enumConstant: (_) {},
          field: (_) {},
          param: (_) {},
          objCCategory: (node) => node.isIncluded = true,
          objCInterface: (node) => node.isIncluded = true,
          objCMethod: (node) => node.isIncluded = true,
          objCProtocol: (node) => node.isIncluded = true,
        ),
      ],
    );

    ffiContext = Context(createDefaultLogger(), generator);

    visitor = C2DartVisitor();
    visitor.context = ffiContext;

    ffiLibrary = parse(ffiContext);
    writer = c2DartWriter(context);
  }

  void collect() => writer._visit();

  Future<void> writeOutput({bool format = false}) async {
    await File(outputDartFile.toFilePath()).writeAsString(writer.writeContent());
    if (format) await this.format(outputDartFile.toFilePath());
  }

  Future<void> format(String outputPath) async {
    final file = File(outputPath);
    // NOTE: stolen from ffigen
    final result = await Process.run(dartExecutable, [
      'format',
      file.absolute.path,
    ], workingDirectory: file.parent.absolute.path);
    if (result.exitCode != 0) {
      context.c2Dart.ffiContext.logger.severe('Formatting failed\n${result.stdout}\n${result.stderr}');
    }
  }
}