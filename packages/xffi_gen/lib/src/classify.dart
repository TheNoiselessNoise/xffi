part of '../xffi_gen.dart';

final class XCollection {
  Map<String, Struct> structs = {};
  Map<String, XStructDecl> classifiedStructs = {};

  Map<String, Typealias> typeAliases = {};
  Map<String, EnumClass> enums = {};
  Map<String, Func> funcs = {};
  Map<String, MacroConstant> macroConstants = {};
  Map<String, Constant> constants = {};
}

final class XContext {
  final XGeneratorConfig config;
  final String outputPath;
  late C2Dart c2Dart;
  late TypeResolver typeResolver;
  final XCollection collection = .new();
  
  XContext(this.config, this.outputPath) {
    typeResolver = .new(this);
  }

  ParsedType parseType(CompoundMember member, {String? message}) {
    String nativeType = member.type.getNativeType(ffiContext);
    return typeResolver.parseTypeOrThrow(nativeType, message: message);
  }

  C2DartVisitor get visitor => c2Dart.visitor;
  Context get ffiContext => c2Dart.ffiContext;
  W getWriter<W extends C2DartWriter>() => c2Dart.writer as W;
}

void classifyStructs(XContext ctx, XGeneratorConfig config) {
  for (final MapEntry(key: name, value: struct) in ctx.visitor.structs.entries) {
    if (config.structModes[name] == .skip) continue;

    final fieldNames = struct.members.map((f) => f.name).toSet();

    final decl = XStructDecl(name, []);
    final List<XFieldDecl> fields = [];
    for (final member in struct.members) {
      final kind = _classifyField(ctx,
        structName: decl.name,
        field: member,
        siblingNames: fieldNames,
      );

      XTypeRef typeRef = XVoidType();
      decl.fields.add(XFieldDecl(name, typeRef, kind: kind));
    }
    decl.fields.addAll(fields);
    ctx.visitor.classifiedStructs[name] = decl;
  }
}

XFieldKind _classifyField(XContext ctx, {
  required String structName,
  required CompoundMember field,
  required Set<String> siblingNames,
}) {
  final type = field.type.getNativeType(ctx.ffiContext);

  if (type is! XPointerType) {
    if (type is XNamedType && ctx.visitor.structs.containsKey(type)) {
      return .nestedStruct;
    }
    return .scalar;
  }

  final override = ctx.config.overrideFor(structName, field.name);
  if (override is XOpaque) return .opaquePointer;
  if (override is XFixedLength) {
    throw StateError(
      "XFixedLength is not implemented",
    );
    // field.type = XFixedArrayType(type.pointee, override.length);
    // return XFieldKind.fixedArray;
  }
  if (override is XLengthField) {
    if (!siblingNames.contains(override.fieldName) && !override.isExternal) {
      throw StateError(
        "Config says '$structName.${field.name}' is length-counted by "
        "'${override.fieldName}', but $structName has no such field.",
      );
    }
    return .dynamicArray;
  }

  final guessedLengthField = _guessLengthField(field.name, siblingNames);
  if (guessedLengthField != null) return .dynamicArray;

  throw StateError('missing pointee');

  // throw StateError(
  //   "Can't classify pointer field '$structName.${field.name}' "
  //   "(${type.pointee.runtimeType} pointer): no sibling '<name>Count'-style "
  //   "field found, and no config.fieldOverrides['$structName.${field.name}'] "
  //   "given. Add a FixedLength/LengthField/Opaque override for it.",
  // );
}

String? _guessLengthField(String pointerFieldName, Set<String> siblingNames) {
  final candidates = {
    '${pointerFieldName}Count',
    'n${_capitalize(pointerFieldName)}',
    'num${_capitalize(pointerFieldName)}',
  };
  return candidates.where(siblingNames.contains).firstOrNull;
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';