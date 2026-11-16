part of '../xffi_gen.dart';

final class ParsedType {
  final ParsedType? innerType;
  final PredefinedCType nativeType;
  final int arrayLength;
  final bool isStruct;
  final bool isEnum;

  ParsedType({
    required this.nativeType,
    this.innerType,
    this.arrayLength = 0,
    this.isStruct = false,
    this.isEnum = false,
  }) {
    if (isStruct && innerType != null) throw UnsupportedError("Struct can't have an inner type!");
    if (isEnum && innerType != null) throw UnsupportedError("Enum can't have an inner type!");
  }

  factory ParsedType.scalar(PredefinedCType type) => .new(nativeType: type);
  factory ParsedType.struct(PredefinedCType type) => .new(nativeType: type, isStruct: true);
  factory ParsedType.enumeration(PredefinedCType type) => .new(nativeType: type, isEnum: true);

  bool get isValue => isStruct || isEnum && innerType == null;
  bool get isPointer => innerType != null && arrayLength == 0 && !isValue;
  bool get isPointerPointer => isPointer && (innerType?.isPointer ?? false);
  bool get isArray => innerType != null && arrayLength > 0 && !isValue;

  PredefinedCType get _baseType {
    ParsedType? current = innerType;
    while (current?.innerType != null) {
      current = current!.innerType;
    }
    return current?.nativeType ?? nativeType;
  }

  ParsedType get rootType {
    ParsedType current = this;
    while (current.innerType != null) {
      current = current.innerType!;
    }
    return current;
  }

  String get baseNativeType => _baseType.nativeType;
  String get baseFfiType => _baseType.ffiType;
  String get baseFlatType => _baseType.flatType;
  String get scalarDartType => _baseType.dartType;
  String get baseDartType {
    final dartType = _baseType.dartType;
    if (isArray || isPointer) return 'List<$dartType>';
    return dartType;
  }

  String get flatTypeRaw {
    String type = nativeType.flatType;
    if (innerType == null) {
      if (isStruct) return 'XStructType';
      return type;
    }

    ParsedType? current = innerType;
    while (current != null) {
      if (current.isStruct) {
        final name = current.nativeType.dartType;
        type = '$type<XStructType($name.struct)>';
      } else {
        type = '$type<${current.flatTypeRaw}>';
      }
      current = current.innerType;
    }
    return type;
  }

  String flatTypeInstance([String? arrayLength]) {
    String type = nativeType.flatType;
    if (innerType == null) {
      if (isStruct) {
        final name = nativeType.dartType;
        return 'XStructType($name.struct)';
      } else {
        return '$type()';
      }
    } else if (isArray) {
      return 'RArray(${innerType!.flatTypeInstance(arrayLength)}, ${arrayLength!})';
    }

    ParsedType? current = innerType;
    while (current != null) {
      type = '$type(${current.flatTypeInstance(arrayLength)})';
      current = current.innerType;
    }
    return type;
  }
}

final class PredefinedCType {
  final String nativeType;
  final String ffiType;
  final String flatType;
  final String dartType;

  PredefinedCType(
    this.nativeType,
    this.ffiType,
    this.flatType,
    this.dartType,
  );

  factory PredefinedCType.type(String name) => .new(name, name, name, name);
}

final class TypeResolver {
  final XContext ctx;

  TypeResolver(this.ctx);

  // <ctype, ffi & dart type>
  static PredefinedCType? parseBaseType(String type) => <String, PredefinedCType>{
    // pointer (special cases)
    '__ptr__':                .new('*', 'Pointer', 'XPtrType', 'int'),
    '__arr__':                .new('[]', 'Array', 'RArray', 'List'),

    // void
    'void':                   .new('void', 'Void', 'RVoid', 'void'),

    // bool
    'bool':                   .new('bool', 'Bool', 'RBool', 'bool'),

    // float / double
    'float':                  .new('float', 'Float', 'RFloat', 'double'),
    'double':                 .new('double', 'Double', 'RDouble', 'double'),

    // signed integers
    'char':                   .new('char', 'Char', 'RChar', 'int'),
    'short':                  .new('short', 'Short', 'RShort', 'int'),
    'short int':              .new('short int', 'Short', 'RShort', 'int'),
    'int':                    .new('int', 'Int', 'RInt', 'int'),
    'long':                   .new('long', 'Long', 'RLong', 'int'),
    'long int':               .new('long int', 'Long', 'RLong', 'int'),
    'long long':              .new('long long', 'LongLong', 'RLongLong', 'int'),
    'long long int':          .new('long long int', 'LongLong', 'RLongLong', 'int'),

    // unsigned integers
    'unsigned char':          .new('unsigned char', 'UnsignedChar', 'RUnsignedChar', 'int'),
    'unsigned short':         .new('unsigned short', 'UnsignedShort', 'RUnsignedShort', 'int'),
    'unsigned short int':     .new('unsigned short int', 'UnsignedShort', 'RUnsignedShort', 'int'),
    'unsigned int':           .new('unsigned int', 'UnsignedInt', 'RUnsignedInt', 'int'),
    'unsigned long':          .new('unsigned long', 'UnsignedLong', 'RUnsignedLong', 'int'),
    'unsigned long int':      .new('unsigned long int', 'UnsignedLong', 'RUnsignedLong', 'int'),
    'unsigned long long':     .new('unsigned long long', 'UnsignedLongLong', 'RUnsignedLongLong', 'int'),
    'unsigned long long int': .new('unsigned long long int', 'UnsignedLongLong', 'RUnsignedLongLong', 'int'),

    // stdint.h exact-width
    'int8_t':                 .new('int8_t', 'Int8', 'RInt8', 'int'),
    'int16_t':                .new('int16_t', 'Int16', 'RInt16', 'int'),
    'int32_t':                .new('int32_t', 'Int32', 'RInt32', 'int'),
    'int64_t':                .new('int64_t', 'Int64', 'RInt64', 'int'),
    'uint8_t':                .new('uint8_t', 'Uint8', 'RUint8', 'int'),
    'uint16_t':               .new('uint16_t', 'Uint16', 'RUint16', 'int'),
    'uint32_t':               .new('uint32_t', 'Uint32', 'RUint32', 'int'),
    'uint64_t':               .new('uint64_t', 'Uint64', 'RUint64', 'int'),

    // stddef.h / sys types
    'size_t':                 .new('size_t', 'Size', 'RSize', 'int'),
    'ssize_t':                .new('ssize_t', 'IntPtr', 'RSsize', 'int'),
    'intptr_t':               .new('intptr_t', 'IntPtr', 'RIntPtr', 'int'),
    'uintptr_t':              .new('uintptr_t', 'UintPtr', 'RUintPtr', 'int'),
    'ptrdiff_t':              .new('ptrdiff_t', 'IntPtr', 'RPtrDiff', 'int'),
  }[type];

  final _bareSign = RegExp(
    r'\b(unsigned|signed)\b(?!\s*(?:int|char|short|long|__int8|__int16|__int32|__int64|__int128)\b)'
  );

  ParsedType parseTypeOrThrow(String type, {String? message})
    => parseType(type) ?? (throw StateError("Unable to parse native type '$type', source: ${message ?? 'unknown'}"));

  ParsedType _wrapPointer(int ptrCount, ParsedType baseType) {
    ParsedType current = baseType;
    while (ptrCount-- > 0) {
      current = .new(
        nativeType: parseBaseType('__ptr__')!,
        innerType: current,
      );
    }
    return current;
  }

  ParsedType? parseType(String type) {
    type = type.trim();

    // fix type
    type = type.replaceAllMapped(_bareSign, (m) => '${m[1]} int').trim();

    // base type
    final baseType = parseBaseType(type);
    if (baseType != null) return .new(nativeType: baseType);

    final ptrCount = '*'.allMatches(type).length;
    String strippedType = type.replaceAll('*', '').trim();

    // struct (or pointer to struct)
    Struct? struct = ctx.visitor.structs[strippedType];
    if (struct == null && type.startsWith('struct ')) {
      strippedType = strippedType.substring('struct '.length);
      struct = ctx.visitor.structs[strippedType];
    }
    if (struct != null) return _wrapPointer(ptrCount, .struct(.type(struct.name)));

    final enum_ = ctx.visitor.enums[type];
    if (enum_ != null) return _wrapPointer(ptrCount, .enumeration(.type(enum_.name)));

    // base type pointer
    if (ptrCount > 0) {
      final base = parseBaseType(strippedType);
      if (base == null) throw UnsupportedError('BASEPTR $type: unknown base type');
      return _wrapPointer(ptrCount, .scalar(base));
    }

    // arrays
    final arrMatch = RegExp(r'^(.+)\[(\d+)\]$').firstMatch(type.trim());
    if (arrMatch != null) {
      final innerType = arrMatch.group(1)!.trim();
      final length = int.parse(arrMatch.group(2)!);
      final inner = parseType(innerType);
      if (inner == null) throw UnsupportedError('ARR $type: unknown inner type');
      return _wrapPointer(ptrCount, .new(
        nativeType: parseBaseType('__arr__')!,
        innerType: inner,
        arrayLength: length,
      ));
    }

    return null;
  }
}