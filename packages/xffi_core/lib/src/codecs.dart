part of '../xffi_core.dart';

/// A codec for a single value of type [E], stored at an [X]-typed region of
/// memory (the field's own on-struct type, for a pointer field this is
/// `XPtrType<Pointee>`, not `Pointee`).
abstract class XElementCodec<E, X extends XType> {
  /// Native type describing the memory region this codec reads and writes.
  final X type;

  const XElementCodec(this.type);

  /// Throws [StateError] if [p] is null, naming [action] in the message.
  void _check(XPtr p, String action) {
    if (p.isNull) throw StateError('You are trying to $action on a nullptr.');
  }

  /// Reads a value of type [E] from the memory at [p].
  E read(XPtr p);

  /// Writes [value] to the memory at [p].
  void write(XPtr p, E value);

  /// Returns the temp allocator this codec uses to allocate backing storage
  /// out of [temp], or `null` if it doesn't allocate.
  XAlloc? allocator();

  /// Allocates any backing storage for a value at [p], using [temp] and
  /// identified by [key]. [count] and [raw] are for codecs that allocate
  /// arrays or need unmanaged memory.
  ///
  /// No-op by default: most codecs (scalar, enum, struct) don't own
  /// pointers, so there's nothing to allocate.
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    // no-op by default, most codecs (Scalar, Enum, Struct) don't own
    // pointers, so there's nothing to allocate.
  }
}

/// Opt-in capability for codecs whose values sit at a fixed byte stride, so
/// a contiguous run of them can be read/written in one call. Not every
/// [XElementCodec] can do this (e.g. [XStringCodec] has no fixed stride),
/// this is deliberately separate from the base contract rather than forced
/// on every codec.
mixin XContiguousCodec<E, X extends XType> on XElementCodec<E, X> {
  /// Reads [count] consecutive values starting at [p].
  List<E> readArray(XPtr p, int count);

  /// Writes [values] consecutively starting at [p].
  void writeArray(XPtr p, List<E> values);
}

final class XStringCodec<X extends XTypeIntLike> extends XElementCodec<String, X> {
  const XStringCodec(super.type);

  @override
  String read(XPtr p) {
    _check(p, 'read string');
    return switch (type) {
      XInt8() => p.cast<XInt8>().toDartString(),
      XInt16() => p.cast<XInt16>().toDartString(),
      XInt32() => p.cast<XInt32>().toDartString(),
      _ => throw UnsupportedError("Invalid type $X for reading a string value."),
    };
  }

  String readString(XPtr p, int maxLength) {
    _check(p, 'readString');
    return switch (type) {
      XInt8() => p.cast<XInt8>().toDartString(maxLength),
      XInt16() => p.cast<XInt16>().toDartString(maxLength),
      XInt32() => p.cast<XInt32>().toDartString(maxLength),
      _ => throw UnsupportedError("Invalid type $X for reading a string value."),
    };
  }

  @override
  void write(XPtr p, String value) {
    _check(p, 'write string');
    return switch (type) {
      XInt8() => p.cast<XInt8>().writeString(value),
      XInt16() => p.cast<XInt16>().writeString(value),
      XInt32() => p.cast<XInt32>().writeString(value),
      _ => throw UnsupportedError("Invalid type $X for writing a string value."),
    };
  }

  void writeString(XPtr p, String value, int maxLength) {
    _check(p, 'writeString');
    return switch (type) {
      XInt8() => p.cast<XInt8>().writeString(value, maxLength),
      XInt16() => p.cast<XInt16>().writeString(value, maxLength),
      XInt32() => p.cast<XInt32>().writeString(value, maxLength),
      _ => throw UnsupportedError("Invalid type $X for writing a string value."),
    };
  }

  @override
  XAlloc? allocator() => XTemp.instance.String$;
}

final class XScalarCodec<E, X extends XType>
  extends XElementCodec<E, X>
  with XContiguousCodec<E, X>
{
  const XScalarCodec(super.type);

  @override
  E read(XPtr p) {
    _check(p, 'read scalar');
    return type.read(p, 0);
  }

  @override
  void write(XPtr p, E value) {
    _check(p, 'write scalar');
    type.write(p, 0, value);
  }

  @override
  List<E> readArray(XPtr p, int count) {
    _check(p, 'read scalar array');
    final stride = type.byteSize;
    return .generate(count, (i) => type.read(p, i * stride));
  }

  @override
  void writeArray(XPtr p, List<E> values) {
    _check(p, 'write scalar array');
    final stride = type.byteSize;
    for (var i = 0; i < values.length; i++) {
      type.write(p, i * stride, values[i]);
    }
  }

  @override
  XAlloc? allocator() => XTemp.instance.scalarAlloc<X>();
}

final class XEnumCodec<E extends XEnum, X extends XType>
  extends XElementCodec<E, X>
  with XContiguousCodec<E, X>
{
  final E Function(int) enumFactory;

  const XEnumCodec(super.type, this.enumFactory);

  @override
  E read(XPtr p) {
    _check(p, 'read enum');
    return enumFactory(type.read(p, 0));
  }

  @override
  void write(XPtr p, E value) {
    _check(p, 'write enum');
    type.write(p, 0, value.value);
  }

  @override
  List<E> readArray(XPtr p, int count) {
    _check(p, 'read enum array');
    final stride = type.byteSize;
    return .generate(count, (i) => enumFactory(type.read(p, i * stride)));
  }

  @override
  void writeArray(XPtr p, List<E> values) {
    _check(p, 'write enum array');
    final stride = type.byteSize;
    for (var i = 0; i < values.length; i++) {
      type.write(p, i * stride, values[i].value);
    }
  }

  @override
  XAlloc? allocator() => XTemp.instance.scalarAlloc<X>();
}

/// A single pointer to unknown value. Typically for [XType]s like [XVoid] or [XOpaque].
final class XUnknownCodec<E, X extends XType> extends XElementCodec<E, X> {
  XUnknownCodec(super.type);

  @override
  XAlloc allocator() => XTemp.instance._pointerAllocator;

  @override
  E read(XPtr p)
    => throw UnsupportedError('Cannot read unknown value.');

  @override
  void write(XPtr p, E value)
    => throw UnsupportedError('Cannot write unknown value.');
}

/// A single pointer to one [E] value.
///
/// [type] is the [XPtrType<R>] describing the pointer field itself;
/// [inner] decodes whatever the pointer points to.
///
/// Two unrelated "array-ish" abilities live here:
///
///  - [readArray]/[writeArray] operate on a contiguous array of pointer
///    slots, e.g. `void* xs[8]`.
///
///  - [readAt]/[writeAt] index into the array pointed to by a single
///    pointer, e.g. `T* xs`.
final class XPtrCodec<E, X extends XType>
  extends XElementCodec<E, XPtrType<X>>
  with XContiguousCodec<E, XPtrType<X>>
{
  /// Codec for the pointed-to value, applied after dereferencing.
  final XElementCodec<E, X> inner;

  const XPtrCodec(super.type, this.inner);

  /// Reads the pointer stored in the slot at [p] and returns it, i.e. `*p`.
  XPtr<Y> deref<Y extends XType>(XPtr p) => p.readPtr();

  /// Whether the pointer stored in the slot at [p] is non-null.
  bool isValid(XPtr p) => !deref(p).isNull;

  @override
  E read(XPtr p) {
    _check(p, 'read pointer');
    return inner.read(deref(p));
  }

  /// Like [read], but returns [fallback] if the pointer stored in the slot
  /// at [p] is null.
  E readSafe(XPtr p, E fallback) {
    final ref = deref(p);
    if (ref.isNull) return fallback;
    return inner.read(ref);
  }

  @override
  void write(XPtr p, E value) => inner.write(deref(p), value);

  /// Like [write], but does nothing if the pointer stored in the slot at
  /// [p] is null.
  void writeSafe(XPtr p, E value) {
    final ref = deref(p);
    if (ref.isNull) return;
    inner.write(ref, value);
  }

  @override
  List<E> readArray(XPtr p, int count) {
    _check(p, 'read pointer array');
    return .generate(count,
      (i) => inner.read(deref(p.offsetBy(i * XType.nativeWordSize))),
    );
  }

  @override
  void writeArray(XPtr p, List<E> values) {
    _check(p, 'write pointer array');
    for (var i = 0; i < values.length; i++) {
      inner.write(deref(p.offsetBy(i * XType.nativeWordSize)), values[i]);
    }
  }

  /// Address of element [index] in the array pointed to by this pointer,
  /// given the address of the pointer *slot* (`fieldPtr`). Dereferences
  /// [fieldPtr] for you, then delegates to [elementPtrFrom].
  ///
  /// For `T* p`, this is `p[index]`, i.e. `*fieldPtr + index * sizeof(T)`.
  XPtr<X> elementPtr(XPtr fieldPtr, int index)
    => elementPtrFrom(deref(fieldPtr), index);

  /// Address of element [index], given a pointer value you've *already*
  /// dereferenced or otherwise resolved (e.g. via [pointerElementPtr]).
  ///
  /// Use this instead of [elementPtr] whenever you're holding the actual
  /// `T*` value rather than the address of a pointer slot, the two are
  /// easy to conflate, and conflating them was the exact bug that motivated
  /// pulling this method out on its own.
  XPtr<X> elementPtrFrom(XPtr derefedBase, int index)
    => derefedBase.offsetBy(index * type.target.byteSize);

  /// Address stored in pointer slot [index]. For `T** p`, this is `p[index]`,
  /// itself a `T*`. Intentionally different from [elementPtr]/[elementPtrFrom].
  XPtr<X> pointerElementPtr(XPtr fieldPtr, int index)
    => fieldPtr.readPtr(index * XType.nativeWordSize);

  /// Reads element [index] of the array pointed to by the pointer slot at
  /// [fieldPtr], i.e. `fieldPtr->[index]` for `T* xs`.
  E readAt(XPtr fieldPtr, int index)
    => inner.read(elementPtr(fieldPtr, index));

  /// Writes [value] to element [index] of the array pointed to by the
  /// pointer slot at [fieldPtr].
  ///
  /// Returns [value].
  E writeAt(XPtr fieldPtr, int index, E value) {
    inner.write(elementPtr(fieldPtr, index), value);
    return value;
  }

  @override
  XAlloc? allocator() => XTemp.instance._pointerAllocator;

  @override
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    if (!deref(p).isNull) return;
    final alloc = inner.allocator();
    if (alloc == null) throw StateError('No allocator for ${inner.runtimeType}');
    final block = raw ? alloc.Raw(count) : alloc.At(key, count);
    p.writePtr(block);
    inner.allocate(block, '${key}_inner', count: count, raw: raw);
  }
}

final class XArrayCodec<E, X extends XType>
  extends XElementCodec<List<E>, XArray<X>>
  with XContiguousCodec<List<E>, XArray<X>>
{
  final XContiguousCodec<E, X> inner;
  final int count;

  const XArrayCodec(super.type, this.inner, this.count);

  @override
  List<E> read(XPtr p) => inner.readArray(p, count);

  @override
  void write(XPtr p, List<E> values) {
    if (values.length != count) throw ArgumentError('Expected $count, got ${values.length}');
    inner.writeArray(p, values);
  }

  @override
  List<List<E>> readArray(XPtr p, int count) {
    // count groups of `this.count` contiguous elements, read them all in one
    // flat pass (so stride/byteSize logic stays entirely in `inner`) and chunk.
    final flat = inner.readArray(p, count * this.count);
    return .generate(
      count,
      (i) => flat.sublist(i * this.count, (i + 1) * this.count),
    );
  }

  @override
  void writeArray(XPtr p, List<List<E>> values) {
    final flat = <E>[];
    for (final group in values) {
      if (group.length != count) {
        throw ArgumentError('Expected $count elements per group, got ${group.length}.');
      }
      flat.addAll(group);
    }
    inner.writeArray(p, flat);
  }

  @override
  XAlloc? allocator() => inner.allocator();

  @override
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    for (var i = 0; i < count; i++) {
      for (var j = 0; j < this.count; j++) {
        inner.allocate(
          p.offsetBy((i * this.count + j) * inner.type.byteSize),
          '${key}_${i}_$j',
          count: 1,
          raw: raw,
        );
      }
    }
  }

  XPtr<X> elementPtr(XPtr fieldPtr, int index)
    => fieldPtr.offsetBy(index * type.element.byteSize);

  E readAt(XPtr fieldPtr, int index) => inner.read(elementPtr(fieldPtr, index));

  E writeAt(XPtr fieldPtr, int index, E value) {
    inner.write(elementPtr(fieldPtr, index), value);
    return value;
  }
}

final class XStructCodec<E extends XStruct<E>>
  extends XElementCodec<E, XStructType>
  with XContiguousCodec<E, XStructType>
{
  const XStructCodec(super.type);

  XStructPtrFactory<E> get wrap => XStructDefinitions.of<E>().ptr;

  @override
  E read(XPtr p) {
    _check(p, 'read struct');
    return wrap(p)[0];
  }

  @override
  void write(XPtr p, E value) {
    _check(p, 'write struct');
    wrap(p).ref = value;
  }

  @override
  List<E> readArray(XPtr p, int count) {
    _check(p, 'read struct array');
    return wrap(p).readArray(count).toList();
  }

  @override
  void writeArray(XPtr p, List<E> values) {
    _check(p, 'write struct array');
    wrap(p).writeArray(values);
  }

  @override
  XAlloc? allocator() => XTemp.instance.structAlloc<E>();
}