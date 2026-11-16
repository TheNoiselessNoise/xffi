part of '../xffi_core.dart';

mixin XFields on Enum {}

/// A float/double leaf at an absolute byte offset (nested structs and arrays flattened).
final class XLayoutFloatSlot {
  final int offset;
  final int size; // 4 or 8, from RFloat/RDouble
  const XLayoutFloatSlot(this.offset, this.size);
}

/// A contiguous run of non-float, non-padding bytes.
final class XLayoutByteRange {
  final int offset;
  final int length;
  const XLayoutByteRange(this.offset, this.length);
}

final class XLayoutFieldInfo {
  final XType type;
  final int offset;
  const XLayoutFieldInfo(this.type, this.offset);

  int get alignment => type.alignment;
  
  int get size => type.byteSize;
}

/// Describes the memory layout of a backend-agnostic struct.
///
/// Computes C-style natural alignment: each field is aligned according to
/// its own alignment requirement, and the total struct size is rounded up
/// to the largest field alignment.
///
/// Also precomputes what value equality needs: float leaves ([floatFields],
/// compared numerically) and non-float leaf bytes ([byteRanges], compared
/// bytewise). Padding belongs to neither, so it is never compared or hashed.
final class XLayout<F extends XFields> {
  /// Each field's [XType] and byte offset from the beginning of the struct.
  final Map<String, XLayoutFieldInfo> fields;

  /// Every float/double leaf with its absolute offset, including those
  /// inside arrays and nested structs.
  final List<XLayoutFloatSlot> floatFields;

  /// Every contiguous run of non-float leaf bytes. Excludes padding and floats.
  final List<XLayoutByteRange> byteRanges;

  /// The total size of the struct in bytes, including trailing alignment.
  final int byteSize;

  /// The alignment requirement of the struct in bytes.
  final int alignment;

  const XLayout._(
    this.fields,
    this.floatFields,
    this.byteRanges,
    this.byteSize,
    this.alignment,
  );

  /// Creates a naturally aligned struct layout from [fields].
  ///
  /// Each field is placed at the next offset satisfying its alignment
  /// requirement. The final struct size is rounded up to the largest
  /// alignment used by any field.
  ///
  /// This matches the layout rules used by C for flat structs containing
  /// primitives and pointers.
  static XLayout<F> aligned<F extends XFields>(Map<F, XType> fields)
    => _build(fields, (k) => k.name);

  static XLayout alignedUntyped(Map<String, XType> fields)
    => _build(fields, (k) => k);

  static XLayout<X> _build<X extends XFields, K>(Map<K, XType> fields, String Function(K) keyBuilder) {
    final info = <String, XLayoutFieldInfo>{};
    var offset = 0;
    var maxAlign = 1;

    for (final entry in fields.entries) {
      final type = entry.value;
      final align = type.alignment;
      offset = (offset + align - 1) ~/ align * align;
      info[keyBuilder(entry.key)] = .new(type, offset);
      offset += type.byteSize;
      if (align > maxAlign) maxAlign = align;
    }

    final total = (offset + maxAlign - 1) ~/ maxAlign * maxAlign;
    assert(
      total <= XConfig.maxStructByteSize,
      '$X StructLayout byteSize ($total) exceeds MAX_STRUCT_BYTE_SIZE',
    );

    final floats = <XLayoutFloatSlot>[];
    final mask = Uint8List(total);
    for (final f in info.values) {
      _walk(f.type, f.offset, floats, mask);
    }

    return XLayout._(info, floats, _maskToRanges(mask), total, maxAlign);
  }

  /// Visits every leaf under [type]: floats go to [floats], everything else
  /// is marked in [mask]. Padding is never visited, so it stays unmarked.
  static void _walk(
    XType type,
    int base,
    List<XLayoutFloatSlot> floats,
    Uint8List mask,
  ) {
    if (type is XFloat || type is XDouble) {
      floats.add(.new(base, type.byteSize));
    } else if (type is XArray) {
      final elemSize = type.element.byteSize;
      for (var i = 0; i < type.count; i++) {
        _walk(type.element, base + i * elemSize, floats, mask);
      }
    } else if (type is XStructType) {
      for (final f in type.struct.layout.fields.values) {
        _walk(f.type, base + f.offset, floats, mask);
      }
    } else {
      mask.fillRange(base, base + type.byteSize, 1);
    }
  }

  static List<XLayoutByteRange> _maskToRanges(Uint8List mask) {
    final ranges = <XLayoutByteRange>[];
    var i = 0;
    while (i < mask.length) {
      if (mask[i] == 0) {
        i++;
        continue;
      }
      final start = i;
      while (i < mask.length && mask[i] != 0) {
        i++;
      }
      ranges.add(.new(start, i - start));
    }
    return ranges;
  }

  /// Returns the byte offset of [field] within the struct.
  int offset(F field) {
    _checkField(field.name);
    return _info(field.name).offset;
  }

  /// Returns the byte offset of [field] within the struct.
  int offsetUntyped(String field) {
    _checkField(field);
    return _info(field).offset;
  }

  XLayoutFieldInfo _info(String name) {
    final info = fields[name];
    if (info == null) {
      throw ArgumentError('`$name` is not a field of this layout.');
    }
    return info;
  }

  X _getFieldAs<X extends XType>(F field) {
    final type = _info(field.name).type;
    if (type is! X) {
      throw ArgumentError(
        'Layout field `${field.name}` is `${type.runtimeType}`, but was requested as `$X`.',
      );
    }
    return type;
  }

  // === Value equality (read-only; never mutates either pointer) ===

  /// Whether the memory at [a] and [b] holds equal values.
  ///
  /// Floats compare numerically (`-0.0 == 0.0`, all NaNs equal, which keeps
  /// `==` reflexive). Other leaves compare bytewise. Padding is ignored.
  bool fieldsEqual(XPtr a, XPtr b) {
    if (byteRanges.isNotEmpty) {
      final va = a.asView<Uint8List>(byteSize);
      final vb = b.asView<Uint8List>(byteSize);
      for (final r in byteRanges) {
        final end = r.offset + r.length;
        for (var i = r.offset; i < end; i++) {
          if (va[i] != vb[i]) return false;
        }
      }
    }

    for (final f in floatFields) {
      final x = _readFloat(a, f);
      final y = _readFloat(b, f);
      if (x != y && !(x.isNaN && y.isNaN)) return false;
    }
    return true;
  }

  /// Hash consistent with [fieldsEqual]: `-0.0` and all NaNs are folded.
  int fieldsHash(XPtr p) {
    var h = 0;

    if (byteRanges.isNotEmpty) {
      final v = p.asView<Uint8List>(byteSize);
      for (final r in byteRanges) {
        final end = r.offset + r.length;
        for (var i = r.offset; i < end; i++) {
          h = (h * 31 + v[i]) & 0x3fffffff;
        }
      }
    }

    for (final f in floatFields) {
      final d = _readFloat(p, f);
      final v = d.isNaN ? 0x7ff8 : (d == 0 ? 0 : d.hashCode);
      h = (h * 31 + v) & 0x3fffffff;
    }
    return h;
  }

  static double _readFloat(XPtr p, XLayoutFloatSlot f) => switch (f.size) {
    4 => p.readFloat32(f.offset),
    8 => p.readFloat64(f.offset),
    _ => throw StateError('Invalid float size: ${f.size}.'),
  };

  void _checkField(String name) {
    if (!fields.containsKey(name)) {
      throw StateError("You have defined a field `$name`, but you didn't provide it in a struct layout.");
    }
  }

  void _checkEnumType(F f, XType type) {
    if (type is! XTypeIntLike) {
      throw ArgumentError(
        "Layout field `${f.name}` has element type `${type.runtimeType}`, which is not int-like. "
        "Enum values require an MemoryTypeIntLike (e.g. RInt8, RUint32)."
      );
    }
  }

  void _checkStringType(F f, XType type, String forWhat) {
    if (type is! XInt8 && type is! XInt16 && type is! XInt32) {
      throw UnsupportedError(
        "Invalid element type ${type.runtimeType} for $forWhat. Use either RInt8, RInt16 or RInt32."
      );
    }
  }

  /// Creates a scalar value field for [f].
  ///
  /// [f] must describe a scalar-compatible [XType].
  XValueField<E, X> scalar<E, X extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<X>(f);
    return .new(offset(f), XScalarCodec(type));
  }

  /// Delegates to [scalar] as a [bool] type of [XBool].
  XValueField<bool, XBool> boolean(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XBool>(f);
    return .new(offset(f), XScalarCodec(type));
  }

  /// Delegates to [scalar] for any [int] type of [XType].
  XValueField<int, X> integer<X extends XTypeIntLike>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<X>(f);
    return .new(offset(f), XScalarCodec(type));
  }

  /// Delegates to [scalar] for any [double] type of [XType].
  XValueField<double, X> float<X extends XTypeFloatLike>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<X>(f);
    return .new(offset(f), XScalarCodec(type));
  }

  /// Creates a nested struct value field for [f].
  XValueField<X, XStructType> struct<X extends XStruct<X>>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XStructType>(f);
    return .new(offset(f), XStructCodec<X>(type));
  }

  /// Creates an enum value field for [f].
  ///
  /// [enumFactory] converts the integer representation stored in memory
  /// into the corresponding [XEnum] value.
  XValueField<E, X> enumValue<
    E extends XEnum,
    X extends XTypeIntLike
  >(F f, E Function(int) enumFactory) {
    _checkField(f.name);
    final type = _getFieldAs<X>(f);
    _checkEnumType(f, type);
    final enumCodec = XEnumCodec(type, enumFactory);
    return .new(offset(f), enumCodec);
  }

  /// Creates a fixed-size character array field for [f].
  ///
  /// The array is interpreted as a null-terminated string using the
  /// character type represented by the field's element type.
  XStringValueField<X> stringAsCharArray<X extends XTypeIntLike>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XArray<X>>(f);
    final element = type.element;
    _checkStringType(f, element, 'char array field');
    return .new(offset(f), XStringCodec(element));
  }

  /// Creates a pointer-to-character string field for [f].
  ///
  /// The field represents a C-style `X*` string pointer, where [X] is an
  /// integer-like character type.
  XPtrValueField<String, X> stringAsPtrChar<X extends XTypeIntLike>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<X>>(f);
    final element = type.target;
    _checkStringType(f, element, 'pointer char field');
    final stringCodec = XStringCodec(element);
    final ptrCodec = XPtrCodec(type, stringCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a fixed-size scalar array field for [f].
  XValueField<List<X>, XArray<Y>> scalarArray<X, Y extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XArray<Y>>(f);
    final scalarCodec = XScalarCodec<X, Y>(type.element);
    final arrayCodec = XArrayCodec(type, scalarCodec, type.count);
    return .new(offset(f), arrayCodec);
  }

  /// Creates a fixed-size nested struct array field for [f].
  XValueField<List<X>, XArray<XStructType>> structArray<X extends XStruct<X>>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XArray<XStructType>>(f);
    final structCodec = XStructCodec<X>(type.element);
    final arrayCodec = XArrayCodec(type, structCodec, type.count);
    return .new(offset(f), arrayCodec);
  }

  /// Creates a pointer-to-scalar field for [f].
  ///
  /// The field represents a C-style `X*` pointer to a scalar value.
  XPtrValueField<T, X> ptrScalar<T, X extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<X>>(f);
    final scalarCodec = XScalarCodec<T, X>(type.target);
    final ptrCodec = XPtrCodec(type, scalarCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer-to-struct field for [f].
  ///
  /// The field represents a C-style `X*` pointer to a nested struct.
  XPtrValueField<X, XStructType> ptrStruct<X extends XStruct<X>>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<XStructType>>(f);
    final structCodec = XStructCodec<X>(type.target);
    final ptrCodec = XPtrCodec(type, structCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer-to-enum field for [f].
  ///
  /// The field represents a C-style `Y*` pointer whose target value is
  /// interpreted as a [XEnum].
  XPtrValueField<X, Y> ptrEnumValue<
    X extends XEnum,
    Y extends XType
  >(F f, X Function(int) enumFactory) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<Y>>(f);
    _checkEnumType(f, type.target);
    final enumCodec = XEnumCodec(type.target, enumFactory);
    final ptrCodec = XPtrCodec(type, enumCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer-to-unknown-value field for [f].
  ///
  /// The pointed-to value is exposed without applying a specialized
  /// scalar, struct, or enum conversion.
  XPtrValueField<dynamic, X> ptrUnknown<X extends XTypeUnknownLike>(F f)
    => ptrSync<dynamic, X>(f);

  /// Create a pointer-to-any-value field for [f].
  ///
  /// The pointed-to value is exposed without applying a specialized
  /// scalar, struct, or enum conversion.
  XPtrValueField<dynamic, X> ptrAny<X extends XType>(F f)
    => ptrSync<dynamic, X>(f);

  /// Creates a synchronized pointer field for [f].
  ///
  /// Uses [XUnknownCodec] to keep the pointed-to value synchronized without
  /// imposing a specialized value representation.
  XPtrValueField<E, X> ptrSync<E, X extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<X>>(f);
    final unknownCodec = XUnknownCodec<E, X>(type.target);
    final ptrCodec = XPtrCodec(type, unknownCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer to a fixed-size scalar array field for [f].
  ///
  /// The field represents a C-style `Y*` pointing to exactly [XArray.count]
  /// scalar elements.
  XPtrValueField<List<X>, XArray<Y>> ptrScalarFixedArray<X, Y extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<XArray<Y>>>(f);
    final array = type.target;
    final scalarCodec = XScalarCodec<X, Y>(array.element);
    final arrayCodec = XArrayCodec(type.target, scalarCodec, array.count);
    final ptrCodec = XPtrCodec(type, arrayCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer to a fixed-size struct array field for [f].
  ///
  /// The field represents a C-style `X*` pointing to exactly
  /// [XArray.count] nested structs.
  XPtrValueField<List<X>, XArray<XStructType>> ptrStructFixedArray<X extends XStruct<X>>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<XArray<XStructType>>>(f);
    final array = type.target;
    final structCodec = XStructCodec<X>(array.element);
    final arrayCodec = XArrayCodec(type.target, structCodec, array.count);
    final ptrCodec = XPtrCodec(type, arrayCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a variable-length scalar pointer array field for [f].
  ///
  /// The field represents a C-style `Y*` where the number of elements is
  /// determined externally rather than encoded in the struct type.
  XPtrArrayField<X, Y> ptrScalarArray<X, Y extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<Y>>(f);
    final scalarCodec = XScalarCodec<X, Y>(type.target);
    final ptrCodec = XPtrCodec(type, scalarCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a variable-length struct pointer array field for [f].
  ///
  /// The field represents a C-style `X*` pointing to a sequence of nested
  /// structs whose element count is determined externally.
  XPtrArrayField<X, XStructType> ptrStructArray<X extends XStruct<X>>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<XStructType>>(f);
    final structCodec = XStructCodec<X>(type.target);
    final ptrCodec = XPtrCodec(type, structCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer-to-pointer scalar array field for [f].
  ///
  /// The field represents a C-style `Y**`: an outer pointer points to
  /// pointers, and each inner pointer points to a scalar value.
  XPtrArrayField<X, XPtrType<Y>> ptrPtrScalarArray<X, Y extends XType>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<XPtrType<Y>>>(f);
    final scalarCodec = XScalarCodec<X, Y>(type.target.target);
    final innerPtrCodec = XPtrCodec(type.target, scalarCodec);
    final ptrCodec = XPtrCodec(type, innerPtrCodec);
    return .new(offset(f), ptrCodec);
  }

  /// Creates a pointer-to-pointer struct array field for [f].
  ///
  /// The field represents a C-style `X**`: an outer pointer points to
  /// pointers, and each inner pointer points to a nested struct.
  XPtrArrayField<X, XPtrType<XStructType>> ptrPtrStructArray<X extends XStruct<X>>(F f) {
    _checkField(f.name);
    final type = _getFieldAs<XPtrType<XPtrType<XStructType>>>(f);
    final structCodec = XStructCodec<X>(type.target.target);
    final innerPtrCodec = XPtrCodec(type.target, structCodec);
    final ptrCodec = XPtrCodec(type, innerPtrCodec);
    return .new(offset(f), ptrCodec);
  }
}