part of '../xffi_core.dart';

typedef XStructFactory<X extends XStruct<X>> = X Function({ XStructPtr<X>? op });
typedef XStructPtrFactory<X extends XStruct<X>> = XStructPtr<X> Function(XPtr?);

/// XStructDef
final class XStructDef<X extends XStruct<X>> {
  final bool isValue;
  final String? overrideName;
  final XStructFactory<X> factory;
  final XLayout layout;

  bool get isDynamic => X == XDynStruct;
  Type get baseType => X;
  
  late final XStructAlloc<X> _allocator = .new(this);

  XStructDef._({
    this.isValue = false,
    this.overrideName,
    required this.factory,
    required this.layout,
  });

  factory XStructDef.create({
    String? overrideName,
    required XStructFactory<X> factory,
    required XLayout layout,
  }) => ._(
    isValue: false,
    overrideName: overrideName,
    factory: factory,
    layout: layout,
  );

  factory XStructDef.createValue({
    String? overrideName,
    required XStructFactory<X> factory,
    required XLayout layout,
  }) => ._(
    isValue: true,
    overrideName: overrideName,
    factory: factory,
    layout: layout,
  );

  static bool _isTypePlain(XType t) => switch (t) {
    XTypeScalarLike() => true,
    XPtrType() => false,
    XArray(:final element) => _isTypePlain(element),
    XStructType(:final struct) => struct.layout.fields.values.every((f) => _isTypePlain(f.type)),
    _ => false,
  };

  static void _checkFields(Map<String, XType> fields, String name) {
    for (final e in fields.entries) {
      final path = "$name.${e.key}";
      final f = e.value;

      if (f is XString && f.maxLength == null) {
        throw StateError(
          'RString field "$path" requires maxLength when used directly. '
          'Use XPtrType(RString()) to allocate storage based on the provided String.',
        );
      }

      if (f is XArray) {
        final el = f.element;

        if (el is XString && el.maxLength == null) {
          throw StateError(
            'RString array element "$path" requires maxLength. '
            'Use XPtrType(RString()) to allocate storage based on the provided String.',
          );
        }
      }
    }
  }

  static XStructDef<XDynStruct> createDynamic(Map<String, XType> fields, {
    String? name,
    bool? value
  }) {    
    late XStructDef<XDynStruct> type;

    value ??= fields.values.every(_isTypePlain);
    name ??= '${value ? 'value_' : 'non_value_'}${fields.hashCode}';

    _checkFields(fields, name);

    type = ._(
      isValue: value,
      overrideName: name,
      factory: ({op}) => XDynStruct._(op: op, dynType: type),
      layout: .alignedUntyped(fields),
    );

    XStructDefinitions.registerDynamic(name, type);

    return type;
  }

  String get typeName => overrideName ?? X.toString();
  String _allocKey(XPtr ptr) => '$typeName:${ptr.hex}';

  Map<String, dynamic> _describeType(XType type) {
    if (type is XStructType) return {
      'structType': type.struct.typeName,
    };

    if (type is XFunction) return {
      'functionType': type.functionType,
    };

    if (type is XString) return {
      'unitType': type.unitType,
    };

    if (
      type is XBool ||
      type is XTypeIntLike ||
      type is XTypeFloatLike ||
      type is XTypeUnknownLike
    ) return {};

    if (type is XPtrType) throw StateError('unreachable');
    if (type is XArray) throw StateError('unreachable');

    throw UnsupportedError('Unknown type ${type.runtimeType} for unwrap.');
  }

  Map<String, dynamic> toJson() => {
    'name': typeName,
    'isValue': isValue,
    'byteSize': layout.byteSize,
    'alignment': layout.alignment,
    'fields': layout.fields.entries.map((f) => {
      'name': f.key,
      'offset': f.value.offset,
      'baseType': f.value.type.baseType.runtimeType.toString(),
      ..._describeType(f.value.type.baseType),
      'size': f.value.size,
      'alignment': f.value.alignment,
    }).toList(),
    'floatFields': layout.floatFields.map((ff) => {
      'offset': ff.offset,
      'size': ff.size,
    }).toList(),
    'byteRanges': layout.byteRanges.map((br) => {
      'offset': br.offset,
      'length': br.length,
    }).toList(),
  };

  XLayoutFieldInfo _field(String name)
    => layout.fields[name] ?? (throw StateError('No field named "$name" in $typeName.'));

  /// Prints a hexadecimal dump of the memory occupied by this struct.
  ///
  /// [bytesPerLine] specifies the number of bytes displayed per line.
  void dump(XPtr ptr, [int bytesPerLine = 16]) {
    assert(bytesPerLine % 4 == 0);

    final bytes = ptr.asView<Uint8List>(byteSize);
    for (int i = 0; i < bytes.length; i += bytesPerLine) {
      final end = (i + bytesPerLine < bytes.length) ? i + bytesPerLine : bytes.length;
      final chunk = bytes.sublist(i, end);
      final hexString = chunk.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print('${i.toRadixString(16).padLeft(4, '0')}: $hexString');
    }
  }

  dynamic _read(XPtr at, XType type) => switch (type) {
    XTypeScalarLike() => type.read(at, 0),
    XStructType(:final struct) => struct.peek(at),
    XArray(:final element, :final count) => [
      for (var i = 0; i < count; i++)
        _read(at.offsetBy(i * element.byteSize), element),
    ],
    XPtrType(:final target) => _readPointer(at.readPtr(), target),
    XString() => type.read<String>(at, 0),
    _ => throw UnsupportedError('Cannot peek type ${type.runtimeType}.'),
  };

  dynamic _readPointer(XPtr p, XType target)
    => p.isNull ? null : _read(p, target);

  /// Reads the value of a single field from memory.
  ///
  /// [name] is the name of the field to read.
  dynamic peekField(XPtr ptr, String name) {
    final field = _field(name);
    return _read(ptr.offsetBy(field.offset), field.type);
  }

  /// Reads all fields from memory and returns their values as a map.
  ///
  /// The returned map contains field names as keys and their decoded values as values.
  Map<String, dynamic> peek(XPtr ptr) => {
    for (final f in layout.fields.entries)
      f.key: _read(ptr.offsetBy(f.value.offset), f.value.type),
  };

  void _write(XPtr at, XType type, dynamic value, String parentName, String fieldName) {
    String path = '$parentName.$fieldName';

    switch (type) {
      case XTypeScalarLike():
        type.write(at, 0, value);

      case XStructType(:final struct):
        if (value is! Map) {
          throw ArgumentError('$path: expected Map for ${struct.typeName}, got ${value.runtimeType}.');
        }
        struct.poke(at, .from(value));

      case XArray(:final element, :final count):
        if (value is! List) {
          throw ArgumentError('$path: expected List (max $count), got ${value.runtimeType}.');
        }
        if (value.length > count) {
          throw ArgumentError('$path: expected max $count values, got ${value.length}.');
        }
        final stride = element.byteSize;
        for (var i = 0; i < value.length; i++) {
          _write(at.offsetBy(i * stride), element, value[i], path, i.toString());
        }

      case XPtrType(:final target):
        final p = at.readPtr();
        if (p.isNull) throw StateError('$path: pointer is null, allocate it first (allocWith).');
        _write(p, target, value, parentName, fieldName);

      case XString(:final maxLength):
        if (value is! String) {
          throw ArgumentError('$path: expected String, got ${value.runtimeType}.');
        }
        final length = type.lengthOf(value);
        if (maxLength != null && length > maxLength) {
          throw ArgumentError('$path: string length $length exceeds maxLength $maxLength.');
        }
        type.write(at, 0, value);

      default:
        throw UnsupportedError('$path: cannot write type ${type.runtimeType}.');
    }
  }

  /// Writes values to existing fields in memory.
  ///
  /// [values] maps field names to the values to write. Fields not included
  /// in the map remain unchanged.
  ///
  /// This does not allocate or reallocate memory for pointer fields.
  void poke(XPtr ptr, Map<String, dynamic> values) {
    for (final MapEntry(key: name, :value) in values.entries) {
      final field = _field(name);
      if (value == null) continue;
      _write(ptr.offsetBy(field.offset), field.type, value, typeName, name);
    }
  }

  void _requirePlain(XStructType s, String path) {
    if (!s.struct.isValue) {
      throw UnsupportedError('$path: pointee struct ${s.struct.typeName} must be a value struct (no pointers).');
    }
  }

  // returns (innermost leaf type, total leaf count)
  (XType, int) _flatten(XType t, [int mult = 1]) => switch (t) {
    XArray(:final element, :final count) => _flatten(element, mult * count),
    _ => (t, mult),
  };

  XPtr _allocPointee(XType target, dynamic value, String key, String path) {
    switch (target) {
      case XTypeScalarLike():
        return XTemp.instance.scalarAlloc(target).At(key);
      case XStructType():
        _requirePlain(target, path);
        return XTemp.instance.structAllocUntyped(target.struct).At(key);
      case XArray():
        final (leaf, n) = _flatten(target);
        return switch (leaf) {
          XTypeScalarLike() => XTemp.instance.scalarAlloc(leaf).At(key, n),
          XStructType() => (() {
            _requirePlain(leaf, path);
            return XTemp.instance.structAllocUntyped(leaf.struct).At(key, n);
          })(),
          _ => throw UnsupportedError('$path: unsupported array leaf ${leaf.runtimeType} (pointers inside pointees are not supported).'),
        };
      case XString(:final maxLength):
        if (value is! String) {
          throw ArgumentError('$path: expected String, got ${value.runtimeType}.');
        }
        final units = (maxLength ?? target.lengthOf(value)) + 1; // +1 for terminator
        return XTemp.instance.scalarAlloc(target.unitType).At(key, units);
      default:
        throw UnsupportedError('$path: pointer to pointer is not supported in allocWith.');
    }
  }

  /// Allocates storage for pointer fields and initializes fields with values.
  ///
  /// [values] maps field names to the values to initialize. Pointer fields
  /// receive newly allocated storage sized according to their values.
  ///
  /// Unlike [poke], this method may allocate memory for pointer fields.
  void allocWith(XPtr ptr, Map<String, dynamic> values) {
    for (final MapEntry(key: name, :value) in values.entries) {
      final field = _field(name);
      final type = field.type;
      if (type is! XPtrType || value == null) continue;

      final slot = ptr.offsetBy(field.offset);
      if (!slot.readPtr().isNull) continue;

      final path = '$typeName.$name';
      final mem = _allocPointee(type.target, value, '${_allocKey(ptr)}:$name', path);
      _write(mem, type.target, value, typeName, name); // write first, publish pointer after
      slot.writePtr(mem);
    }
  }

  /// Gets the [layout] typed to fields [F].
  XLayout<F> layoutOf<F extends XFields>()
    => layout as XLayout<F>;

  /// Wraps [ptr] as a [XStructPtr]; if [ptr] is `null`, the returned
  /// [XStructPtr] wraps [XPtr.nullptr].
  XStructPtr<X> ptr(XPtr? ptr) => .new(ptr?._base ?? .nullptr(), this);

  /// See [XPtr.malloc].
  XStructPtr<X> malloc([int count = 1]) => ptr(.malloc(byteSize * count));

  /// See [XPtr.calloc].
  XStructPtr<X> calloc([int count = 1]) => ptr(.calloc(count, byteSize));

  /// [XStructPtr] which wraps [XPtr.nullptr].
  XStructPtr<X> nullptr() => .new(.nullptr(), this);

  /// The total size of the struct in bytes, including trailing alignment.
  int get byteSize => layout.byteSize;
}

/// Registry of [XStructDef]s
final class XStructDefinitions {
  static final Map<Type, XStructDef> _types = {};
  static final Map<String, XStructDef> _dynamicTypes = {};

  static Type _key(Object o) => switch (o) {
    Type t => t,
    XStructDef s => s.baseType,
    XStruct s => s.runtimeType,
    _ => throw ArgumentError.value(o, 'type', 'expected Type, XStructDef or MemoryStruct'),
  };

  static bool contains(Object type) => _types.containsKey(_key(type));

  static XStructDef dynamic(String name)
    => _dynamicTypes[name] ?? (throw StateError('No dynamic XStructDef registered for $name.'));

  static void registerDynamic(String name, XStructDef type) {
    if (_dynamicTypes.containsKey(name)) {
      throw StateError('XStructDef for $name is already registered.');
    }
    _dynamicTypes[name] = type;
  }

  /// Unregisters dynamic [XStructDef]/s.
  /// 
  /// If [name] is passed, unregisters given [XStructDef] (if any).
  /// 
  /// If [name] is `null` unregisters all registered [XStructDef]s.
  static void unregisterDynamic([Object? name]) {
    if (name != null) {
      if (name is String) {
        _dynamicTypes.remove(name);
      } else if (name is XStructDef && name.isDynamic) {
        _dynamicTypes.remove(name.typeName);
      } else if (name is XDynStruct) {
        _dynamicTypes.remove(name.structType.typeName);
      }
    } else {
      _dynamicTypes.clear();
    }
  }

  /// Registers a [XStructDef].
  static void register(XStructDef type) {
    if (_types.containsKey(type.baseType)) {
      throw StateError('XStructDef for ${type.baseType} is already registered.');
    }
    _types[type.baseType] = type;
  }

  /// Untyped lookup by [type].
  static XStructDef ofUntyped(Object type)
    => _types[_key(type)] ?? (throw StateError('No XStructDef registered for ${_key(type)}.'));

  /// Typed lookup by [X].
  static XStructDef<X> of<X extends XStruct<X>>() => ofUntyped(X) as XStructDef<X>;
}