part of '../../xffi_core.dart';

/// Extends [XAlloc] with the ability to write individual
/// Dart values directly into allocated memory.
final class XScalarAlloc<X, Y extends XType> extends XArrayAlloc<X, Y> {
  /// [XType] for this allocator.
  late final Y scalarType = XScalarTypes.of<Y>();

  @override
  int get byteSize => scalarType.byteSize;

  @override
  void writeElement(XPtr<Y> ptr, int i, X value)
    => scalarType.writeIndexed(ptr, i, value);

  /// Returns the pointer for the slot identified by [key] (default: `default`),
  /// writing [value] into it when provided.
  ///
  /// Allocates the slot on first use.
  XPtr<Y> Value([X? value, String? key]) {
    final p = At(_slotKey(key));
    if (value != null) writeElement(p, 0, value);
    return p;
  }

  /// Returns the pointer for the slot identified by a unique [key] suffix
  /// writing [value] into it when provided.
  ///
  /// Behaves like [Value], but prepends a monotonic ID from [XTemp.nextId] to
  /// [key], ensuring the slot is never accidentally shared with an unrelated
  /// call that happens to use the same base key.
  XPtr<Y> ValueUnique([X? value, String? key]) {
    final p = At(_uniqueSlotKey(key));
    if (value != null) writeElement(p, 0, value);
    return p;
  }

  /// Writes [o] into slot `@ref:1` and returns its pointer.
  ///
  /// and the callee expects `nullptr` in that case.
  XPtr<Y> Ref1([X? o]) => Value(o, '@ref:1');

  /// Writes [o] into slot `@ref:2` and returns its pointer.
  ///
  /// and the callee expects `nullptr` in that case.
  XPtr<Y> Ref2([X? o]) => Value(o, '@ref:2');

  /// Writes [o] into slot `@ref:3` and returns its pointer.
  ///
  /// and the callee expects `nullptr` in that case.
  XPtr<Y> Ref3([X? o]) => Value(o, '@ref:3');

  /// Writes [o] into slot `@ref:4` and returns its pointer.
  ///
  /// and the callee expects `nullptr` in that case.
  XPtr<Y> Ref4([X? o]) => Value(o, '@ref:4');

  /// Writes [o] into slot `@ref:1` and returns its pointer, or returns `nullptr`
  /// if [o] is `null`.
  ///
  /// Use this instead of [Ref1] when the C API uses a null pointer to signal "no value".
  XPtr<Y> RefOrNull1(X? o) => o == null ? .nullptr() : Ref1(o);

  /// Writes [o] into slot `@ref:2` and returns its pointer, or returns `nullptr`
  /// if [o] is `null`.
  ///
  /// Use this instead of [Ref2] when the C API uses a null pointer to signal "no value".
  XPtr<Y> RefOrNull2(X? o) => o == null ? .nullptr() : Ref2(o);

  /// Writes [o] into slot `@ref:3` and returns its pointer, or returns `nullptr`
  /// if [o] is `null`.
  ///
  /// Use this instead of [Ref3] when the C API uses a null pointer to signal "no value".
  XPtr<Y> RefOrNull3(X? o) => o == null ? .nullptr() : Ref3(o);

  /// Writes [o] into slot `@ref:4` and returns its pointer, or returns `nullptr`
  /// if [o] is `null`.
  ///
  /// Use this instead of [Ref4] when the C API uses a null pointer to signal "no value".
  XPtr<Y> RefOrNull4(X? o) => o == null ? .nullptr() : Ref4(o);

  /// Fixed scratch slot holding a zero-initialized value.
  ///
  /// This is effectively the native-memory equivalent of a Dart-layer
  /// `.zero()` constructor (e.g. `Vector2.zero()`), a cheap, shared,
  /// always-zero buffer for call sites that just need to pass a zero value
  /// without allocating.
  ///
  /// **Read-only by convention.** Because this slot is shared (via [At])
  /// across every call site that touches [$zeroPtr], writing through it
  /// permanently corrupts the "zero" invariant for everyone else using it,
  /// there is no reset. Never write through this pointer; only read from it
  /// or pass it where the callee treats it as `const`. If you need a
  /// mutable zero-initialized buffer, use [$newPtr] (or write zero into
  /// [$1Ptr]..[$4Ptr] yourself) instead.
  XPtr<Y> get $zeroPtr => At('@reusableZero');

  /// Reusable single-element scratch slot, mutable (unlike [$zeroPtr]).
  XPtr<Y> get $1Ptr => At('@reusable1');
  
  /// Reusable single-element scratch slot, mutable (unlike [$zeroPtr]).
  ///
  /// Use when a call needs a second independent scratch pointer alongside
  /// [$1Ptr] (e.g. writing two out-parameters in the same FFI call).
  XPtr<Y> get $2Ptr => At('@reusable2');
  
  /// Reusable single-element scratch slot, mutable (unlike [$zeroPtr]).
  ///
  /// Use when a call needs a third independent scratch pointer alongside
  /// [$2Ptr] (e.g. writing two out-parameters in the same FFI call).
  XPtr<Y> get $3Ptr => At('@reusable3');
  
  /// Reusable single-element scratch slot, mutable (unlike [$zeroPtr]).
  ///
  /// Use when a call needs a fourth independent scratch pointer alongside
  /// [$3Ptr] (e.g. writing two out-parameters in the same FFI call).
  XPtr<Y> get $4Ptr => At('@reusable4');
  
  /// Fresh, independently-owned scratch pointer, unlike [$zeroPtr]..[$4Ptr].
  ///
  /// Each access gets its own slot via [XAlloc.AtUnique], keyed with a monotonic id,
  /// so it is safe even when the same call site may be active multiple times
  /// at once (recursion, re-entrant calls).
  XPtr<Y> get $newPtr => AtUnique(key: '@newPtr');
}

/// Extends [XScalarAlloc] with typed list interop,
/// the ability to view allocated memory as a Dart `List<X>` and construct
/// a typed list from an iterable.
abstract final class XScalarTypedListAlloc<X extends num, L extends TypedDataList<X>, Y extends XType> extends XScalarAlloc<X, Y> {
  XScalarTypedListAlloc();

  /// Pointer allocator for this type [Y].
  late final XScalarPtrAlloc<X, Y> $ = .new(Array, RawArray);

  L _asView(XPtr ptr, int length) => ptr.asView(length);

  /// Constructs a typed list [L] from an iterable of [X] values.
  L fromList(Iterable<X> list);

  /// Wraps a region of [buffer] as a Dart [L] list without copying.
  ///
  /// Views an existing Dart [ByteBuffer] as an [L], allowing [FromTypedData]
  /// to bulk-copy foreign typed data into a slot without going through raw bytes.
  ///
  /// [offsetInBytes] and [length] are forwarded directly to the underlying
  /// `buffer.asXxxList()` call, so the usual alignment and bounds rules apply.
  L fromBuffer(ByteBuffer buffer, int offsetInBytes, int length);

  /// Returns a Dart `List<X>` with [length] elements copied from [ptr].
  List<X> asDartList(XPtr ptr, int length)
    => _asView(ptr, length).cast();

  /// Returns a [L] with [length] elements copied from [ptr].
  L asTypedList(XPtr ptr, int length)
    => fromList(asDartList(ptr, length));

  /// Allocates (or reuses) a slot of [length] elements and returns its pointer,
  /// without writing any data into it.
  ///
  /// Unlike [Array], the contents are left uninitialized, useful when
  /// the buffer will be populated by a C call rather than from Dart.
  /// [key] defaults to `@sized`.
  XPtr<Y> Sized(int length, {String? key}) => At(key ?? '@sized', length);

  /// Copies [length] elements from [src] into a slot and returns the pointer.
  ///
  /// [key] defaults to `default`.
  XPtr<Y> Copy(XPtr src, int length, {String? key}) {
    final p = At(_slotKey(key), length);
    _asView(p, length).setAll(0, _asView(src, length));
    return p;
  }

  /// Copies [length] elements from a typed list [list] into a slot.
  XPtr<Y> FromTypedList(L list, {String? key}) {
    final p = Sized(list.length, key: key);
    _asView(p, list.length).setAll(0, list);
    return p;
  }

  /// Copies [data] into a slot by reinterpreting its bytes as elements of type [X].
  ///
  /// Unlike [FromTypedList], accepts any [TypedData] regardless of its element
  /// type, converting via the underlying byte buffer. [data] must be a whole
  /// number of [byteSize]-sized elements.
  XPtr<Y> FromTypedData(TypedData data, {String? key}) {
    final byteCount = data.lengthInBytes;
    assert(byteCount % byteSize == 0);
    final length = byteCount ~/ byteSize;
    final p = Sized(length, key: key);
    final src = fromBuffer(data.buffer, data.offsetInBytes, length);
    _asView(p, length).setAll(0, src);
    return p;
  }

  @override
  void dispose() {
    super.dispose();
    $.dispose();
  }
}

/// Specializes [XScalarTypedListAlloc] for integer element types,
/// adding integer-specific allocation helpers on top of the typed list interop.
final class XScalarIntAlloc<L extends TypedDataList<int>, X extends XTypeIntLike> extends XScalarTypedListAlloc<num, L, X> {
  int _convert(num source) => source.toInt();

  @override
  L fromList(Iterable<num> list) => switch (L) {
    const (Uint8List) => Uint8List.fromList(list.map(_convert).toList()) as L,
    const (Int8List) => Int8List.fromList(list.map(_convert).toList()) as L,
    const (Uint16List) => Uint16List.fromList(list.map(_convert).toList()) as L,
    const (Int16List) => Int16List.fromList(list.map(_convert).toList()) as L,
    const (Uint32List) => Uint32List.fromList(list.map(_convert).toList()) as L,
    const (Int32List) => Int32List.fromList(list.map(_convert).toList()) as L,
    const (Uint64List) => Uint64List.fromList(list.map(_convert).toList()) as L,
    const (Int64List) => Int64List.fromList(list.map(_convert).toList()) as L,
    _ => throw UnsupportedError('fromList<$L> not implemented'),
  };

  @override
  L fromBuffer(ByteBuffer buffer, int offsetInBytes, int length) => switch(L) {
    const (Uint8List) => buffer.asUint8List(offsetInBytes, length) as L,
    const (Int8List) => buffer.asInt8List(offsetInBytes, length) as L,
    const (Uint16List) => buffer.asUint16List(offsetInBytes, length) as L,
    const (Int16List) => buffer.asInt16List(offsetInBytes, length) as L,
    const (Uint32List) => buffer.asUint32List(offsetInBytes, length) as L,
    const (Int32List) => buffer.asInt32List(offsetInBytes, length) as L,
    const (Uint64List) => buffer.asUint64List(offsetInBytes, length) as L,
    const (Int64List) => buffer.asInt64List(offsetInBytes, length) as L,
    _ => throw UnsupportedError('fromBuffer<$L> not implemented'),
  };

  /// Serialises [length] words starting at [ptr] to a flat big-endian byte list.
  ///
  /// Each word is split into `byteSize` bytes, most-significant byte first.
  L ToBEBytes(XPtr ptr, int length) =>
    fromList(asDartList(ptr, length).expand((word) =>
      .generate(byteSize, (i) => (word.toInt() >> ((byteSize - 1 - i) * 8)) & 0xFF)
    ));

  /// Serialises [length] words starting at [ptr] to a flat little-endian byte list.
  ///
  /// Each word is split into `byteSize` bytes, least-significant byte first.
  L ToLEBytes(XPtr ptr, int length) =>
    fromList(asDartList(ptr, length).expand((word) =>
      .generate(byteSize, (i) => (word.toInt() >> (i * 8)) & 0xFF)
    ));
}

/// Specializes [XScalarTypedListAlloc] for floating-point element types.
final class XScalarFloatAlloc<L extends TypedDataList<double>, X extends XTypeFloatLike> extends XScalarTypedListAlloc<num, L, X> {
  double _convert(num source) => source.toDouble();

  @override
  L fromList(Iterable<num> list) => switch (L) {
    const (Float32List) => Float32List.fromList(list.map(_convert).toList()) as L,
    const (Float64List) => Float64List.fromList(list.map(_convert).toList()) as L,
    _ => throw UnsupportedError('fromList<$L> not implemented'),
  };

  @override
  L fromBuffer(ByteBuffer buffer, int offsetInBytes, int length) => switch(L) {
    const (Float32List) => buffer.asFloat32List(offsetInBytes, length) as L,
    const (Float64List) => buffer.asFloat64List(offsetInBytes, length) as L,
    _ => throw UnsupportedError('fromBuffer<$L> not implemented'),
  };
}

/// Extends [XAlloc] with the ability to allocate pointer-to-pointer
/// slots, where [X] is the pointee's Dart-side value.
final class XScalarPtrAlloc<X, Y extends XType> extends XAlloc<Y> {
  /// [XType] for this allocator.
  late final Y scalarType = XScalarTypes.of<Y>();

  /// Converts a flat `List<X>` into a tracked pointer array.
  final XPtr<Y> Function(List<X> array, {String? key}) arrayFunc;

  /// Converts a flat `List<X>` into an allocated pointer array.
  ///
  /// The caller is responsible for the lifetime of the inner pointers.
  final XPtr<Y> Function(List<X> array) rawArrayFunc;

  XScalarPtrAlloc(this.arrayFunc, this.rawArrayFunc);

  @override
  int get byteSize => XType.nativeWordSize;

  @override
  String get name => 'XPtrType<$X>';

  /// Writes [array] into a tracked slot of sufficient capacity.
  XPtr<XPtrType> Array(List<List<X>> array, {String? key}) {
    key ??= _slotKey(key);
    final pp = At(key, array.length).cast<XPtrType>();
    for (int i = 0; i < array.length; i++) {
      final innerPtr = arrayFunc(array[i], key: '${key}_$i');
      pp.writePtr(innerPtr, i * byteSize);
    }
    return pp;
  }

  /// Allocates an unslotted pointer-of-pointers from a list of value arrays.
  ///
  /// Each `arrays[i]` is converted via [rawArrayFunc].
  ///
  /// The caller is responsible for freeing the returned pointer.
  XPtr<XPtrType> RawArray(List<List<X>> arrays) {
    final pp = Raw(arrays.length).cast<XPtrType>();
    for (int i = 0; i < arrays.length; i++) {
      final innerPtr = rawArrayFunc(arrays[i]);
      pp.writePtr(innerPtr, i * byteSize);
    }
    return pp;
  }
}

/// Pointer allocator.
final class XPtrAlloc extends XAlloc<XPtrType> {
  @override
  int get byteSize => XType.nativeWordSize;
}