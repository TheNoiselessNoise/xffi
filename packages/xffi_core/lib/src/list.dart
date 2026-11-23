part of '../xffi_core.dart';

/// How a [XLiveList] locates and (de)serializes one element in native
/// memory, given the base pointer [XLiveList] resolves for it.
///
/// Every factory has a different notion of what "base" means (raw field
/// address, address of a pointer slot, an already-dereferenced pointer),
/// each implementation below documents its own, so that meaning is fixed
/// once per case instead of being re-decided (and occasionally gotten
/// wrong) at every call site.
abstract final class _Access<E> {
  /// Reads element [index]. Returns null if unreadable (e.g. a null
  /// pointer along the way for a variable-size collection).
  E? readAt(XPtr base, int index);

  /// Writes element [index]. No-ops if unwritable.
  void writeAt(XPtr base, int index, E value);
}

mixin _PtrAccess {
  XPtrCodec get ptrCodec;
}

/// General-purpose escape hatch.
final class _ClosureAccess<E> implements _Access<E> {
  final E? Function(XPtr fieldPtr, int index) _read;
  final void Function(XPtr fieldPtr, int index, E value) _write;
  const _ClosureAccess(this._read, this._write);

  @override
  E? readAt(XPtr base, int index) => _read(base, index);

  @override
  void writeAt(XPtr base, int index, E value) => _write(base, index, value);
}

/// Fixed-size inline array field: `X xs[N];`.
/// `base` handed to [readAt]/[writeAt] is the field's own address.
final class _InlineArrayAccess<E, X extends XType> implements _Access<E> {
  final XArrayCodec<E, X> codec;
  const _InlineArrayAccess(this.codec);

  @override
  E? readAt(XPtr base, int index) {
    if (codec.elementPtr(base, index).isNull) return null;
    return codec.readAt(base, index);
  }

  @override
  void writeAt(XPtr base, int index, E value) => codec.writeAt(base, index, value);
}

/// Pointer to a variable-length array: `X* xs;`.
/// `base` handed to [readAt]/[writeAt] is the address of the pointer *slot*
/// (not yet dereferenced), [XPtrCodec.elementPtr] derefs it for you.
final class _PointerArrayAccess<E, X extends XType> with _PtrAccess implements _Access<E> {
  final XPtrCodec<E, X> codec;

  const _PointerArrayAccess(this.codec);

  @override XPtrCodec get ptrCodec => codec;

  @override
  E? readAt(XPtr base, int index) {
    if (codec.elementPtr(base, index).isNull) return null;
    return codec.readAt(base, index);
  }

  @override
  void writeAt(XPtr base, int index, E value) => codec.writeAt(base, index, value);
}

/// Pointer to one fixed-size array: `X (*xs)[N];`. One level of indirection
/// to a single inline array, the pointer doesn't move per element, only
/// the offset within what it points to does.
/// `base` handed to [readAt]/[writeAt] is the address of the pointer slot.
final class _PointerToFixedArrayAccess<E, X extends XType> with _PtrAccess implements _Access<E> {
  final XPtrCodec<List<E>, XArray<X>> pointerCodec;
  late final XArrayCodec<E, X> arrayCodec = pointerCodec.inner as XArrayCodec<E, X>;

  _PointerToFixedArrayAccess(this.pointerCodec);

  @override XPtrCodec get ptrCodec => pointerCodec;

  @override
  E? readAt(XPtr base, int index) {
    final derefed = pointerCodec.deref(base);
    if (derefed.isNull) return null;
    return arrayCodec.readAt(derefed, index);
  }

  @override
  void writeAt(XPtr base, int index, E value) {
    final derefed = pointerCodec.deref(base);
    if (derefed.isNull) return;
    arrayCodec.writeAt(derefed, index, value);
  }
}

/// Innermost level of a `T** -> T* -> T[]` chain, once the specific `T*`
/// for one outer index has already been resolved (via
/// [XPtrCodec.pointerElementPtr]).
/// `base` handed to [readAt]/[writeAt] is that already-resolved `T*` value
/// itself, no further dereferencing, just a fixed stride per index.
final class _ResolvedPointerAccess<E, X extends XType> implements _Access<E> {
  final XPtrCodec<E, X> codec;
  const _ResolvedPointerAccess(this.codec);

  @override
  E? readAt(XPtr base, int index) {
    if (base.isNull) return null;
    return codec.inner.read(codec.elementPtrFrom(base, index));
  }

  @override
  void writeAt(XPtr base, int index, E value) {
    if (base.isNull) return;
    codec.inner.write(codec.elementPtrFrom(base, index), value);
  }
}

/// Lazily builds and caches elements that are themselves live lists.
/// Assignment is unsupported: replacing the cached object wouldn't write
/// anything to native memory, and would look like it worked, see
/// [XLiveList.ptrPtrArray].
final class _LazyBuiltAccess<E> implements _Access<E> {
  final E Function(int index) build;
  const _LazyBuiltAccess(this.build);

  @override
  E? readAt(XPtr base, int index) => build(index);

  @override
  void writeAt(XPtr base, int index, E value) {
    throw UnsupportedError(
      'Cannot assign a nested StructLiveList as a value. '
      'Modify the inner list returned by operator [] instead.',
    );
  }
}

final class XLiveList<E, X extends XType> extends ListMixin<E> {
  /// Returns the memory pointer this list resolves elements from.
  ///
  /// Always means "base to hand to [_access]".
  final XPtr? Function() ptrOf;

  final int _offset;
  final int? _fixedCount;
  final _Access<E> _access;

  List<E?> _cache;

  XLiveList._(
    this.ptrOf,
    this._offset,
    this._fixedCount,
    this._access,
    List<E> initial,
  ) : _cache = .of(initial);

  /// General-purpose escape hatch: builds a live list from manual
  /// read/write closures over an already-resolved base pointer ([offset]
  /// is always 0 here, bake any offset into [ptrOf] itself).
  factory XLiveList.live(
    XPtr? Function() ptrOf, {
    int? fixedCount,
    required E? Function(XPtr fieldPtr, int index) readAt,
    required void Function(XPtr fieldPtr, int index, E value) writeAt,
    List<E> initial = const [],
  }) => ._(ptrOf, 0, fixedCount, _ClosureAccess(readAt, writeAt), initial);

  /// Fixed-size inline array field.
  factory XLiveList.array(
    XPtr? Function() ptrOf,
    XValueField<List<E>, XArray<X>> field,
    List<E> initial,
  ) {
    final codec = field.codec as XArrayCodec<E, X>;
    assert(initial.length <= codec.count);
    return ._(ptrOf, field.offset, codec.count, _InlineArrayAccess<E, X>(codec), initial);
  }

  /// Pointer to a variable-size array.
  factory XLiveList.ptrArray(
    XPtr? Function() ptrOf,
    XPtrArrayField<E, X> field,
    List<E> initial,
  ) {
    final codec = field.codec;
    return ._(ptrOf, field.offset, null, _PointerArrayAccess<E, X>(codec), initial);
  }

  /// Pointer to a fixed-size array.
  factory XLiveList.ptrFixedArray(
    XPtr? Function() ptrOf,
    XPtrValueField<List<E>, XArray<X>> field,
    List<E> initial,
  ) {
    final pointerCodec = field.codec;
    final arrayCodec = pointerCodec.inner as XArrayCodec<E, X>;
    assert(initial.length <= arrayCodec.count);
    return ._(ptrOf, field.offset, arrayCodec.count, _PointerToFixedArrayAccess<E, X>(pointerCodec), initial);
  }

  /// Pointer to an array of pointers: `T** -> T* -> T[]`.
  ///
  /// The outer list represents the array of `T*` pointers; every element
  /// is itself a live list over the `T[]` that particular `T*` points to,
  /// built lazily and cached in [nestedCache] as indices are accessed.
  static XLiveList<XLiveList<T, Inner>, XPtrType<Inner>> ptrPtrArray<
    T,
    Inner extends XType
  >(
    XPtr? Function() ptrOf,
    XPtrArrayField<T, XPtrType<Inner>> field,
    List<List<T>> initial,
  ) {
    final outerCodec = field.codec;
    final innerCodec = outerCodec.inner as XPtrCodec<T, Inner>;
    final innerAccess = _ResolvedPointerAccess<T, Inner>(innerCodec);
    final nestedCache = <XLiveList<T, Inner>>[];

    XLiveList<T, Inner> build(int index) {
      while (nestedCache.length <= index) {
        final i = nestedCache.length;
        final initialInner = i < initial.length ? initial[i] : const <Never>[];

        nestedCache.add(._(
          () {
            final outerFieldPtr = ptrOf()?.offsetBy(field.offset);
            if (outerFieldPtr == null) return null;
            final arrayBase = outerCodec.deref(outerFieldPtr);
            if (arrayBase.isNull) return null;
            final resolved = outerCodec.pointerElementPtr(arrayBase, i);
            return resolved.isNull ? null : resolved;
          },
          0,
          null,
          innerAccess,
          initialInner,
        ));
      }
      return nestedCache[index];
    }

    return ._(ptrOf, field.offset, null, _LazyBuiltAccess<XLiveList<T, Inner>>(build), nestedCache);
  }

  // we don't care about nullptr
  void syncFrom(XPtr p, {bool borrow = true}) {
    if (!borrow) return;
    _fieldPtr()?.writePtr(p.readPtr(_offset));
  }

  // we don't care about nullptr
  void syncInto(XPtr p) => p.writePtr(_derefPtr(), _offset);

  XPtr? _fieldPtr([XPtr? src]) => (src ?? ptrOf())?.offsetBy(_offset);

  XPtr? _derefPtr([XPtr? src]) => (src ?? ptrOf())?.readPtr(_offset);

  @override
  int get length => _fixedCount ?? _cache.length;

  @override
  set length(int newLength) {
    if (_fixedCount != null) throw UnsupportedError('fixed-size, length is $_fixedCount');
    _cache.length = newLength;
  }

  @override
  E operator [](int index) {
    final fp = _fieldPtr();
    if (fp != null) return _access.readAt(fp, index)!;
    return _cache[index]!;
  }

  @override
  void operator []=(int index, E value) {
    if (index >= _cache.length) _cache.length = index + 1;
    _cache[index] = value;
    final fp = _fieldPtr();
    if (fp != null) _access.writeAt(fp, index, value);
  }

  /// The current non-live cached representation. Does not force a read.
  List<E> get inner => _cache.cast();

  void setOrAllocate(List<E> value, {String? key, int? length, bool raw = false}) {
    if (_fixedCount != null) assert(value.length <= _fixedCount);
    _cache = .of(value);
    final fp = _fieldPtr();
    if (fp == null) return;

    if (_access case _PtrAccess a) {
      final inner = fp.readPtr();
      if (inner.isNull) {
        final count = length ?? value.length;
        final ptrKey = '${key ?? 'inner'}:${XTemp.instance.nextId()}';
        a.ptrCodec.allocate(fp, ptrKey, count: count, raw: raw);
      }
    }

    for (var i = 0; i < value.length; i++) _access.writeAt(fp, i, value[i]);
  }

  /// Replaces only the local cache; does not touch native memory.
  set raw(List<E> value) => _cache = .of(value);

  List<E> _readLive(XPtr? source, {required int? count, required bool safe}) {
    final resolvedCount = count ?? _fixedCount;
    if (resolvedCount == null) throw StateError('Expected `count`.');
    final fp = _fieldPtr(source);
    if (fp == null) return _cache.cast();
    if (fp.isNull) throw StateError('You are trying to read livelist data from a nullptr.');
    final resolved = <E>[];
    for (var i = 0; i < resolvedCount; i++) {
      final value = _access.readAt(fp, i);
      if (value == null) {
        if (!safe) throw StateError('Cannot read. Invalid memory at index $i.');
        break;
      }
      resolved.add(value);
    }
    _cache = resolved;
    return _cache.cast();
  }

  /// Force a live re-read of [count] elements, refreshing the cache.
  List<E> materialize({int? count, bool safe = false})
    => _readLive(null, count: count, safe: safe);

  /// Reads data from another struct/object pointer.
  List<E> readFrom(XPtr p, {int? count, bool safe = true})
    => _readLive(p, count: count, safe: safe);

  /// Writes cached data into another struct/object pointer.
  void writeInto(XPtr p, [List<E>? values]) {
    values ??= inner;
    final fp = _fieldPtr(p);
    if (fp == null) return;
    if (fp.isNull) throw StateError('You are trying to write livelist cached data into nullptr.');
    for (final (i, v) in values.indexed) _access.writeAt(fp, i, v);
  }
}

typedef StructLiveListStruct<E extends XStruct<E>> = XLiveList<E, XStructType>;

typedef StructLiveListStructNested<E extends XStruct<E>> = XLiveList<XLiveList<E, XStructType>, XPtrType<XStructType>>;

extension StructLiveListNested<E, X extends XType> on XLiveList<List<E>, XPtrType<X>> {
  List<List<E>> get innerNested => _cache.cast();

  set innerNested(List<List<E>> value) {
    if (_fixedCount != null) assert(value.length <= _fixedCount);
    for (var i = 0; i < value.length; i++) {
      if (i >= _cache.length) this[i]; // lazily create the inner live list
      final inner = _cache[i];
      if (inner case XLiveList inner) inner.setOrAllocate(value[i]);
    }
    if (_cache.length > value.length) _cache.length = value.length;
  }
}

extension LiveArrayFieldX<E, X extends XType> on XValueField<List<E>, XArray<X>> {
  XLiveList<E, X> live(XPtr? Function() ptrOf, List<E> initial)
    => .array(ptrOf, this, initial);
}

extension LivePtrArrayFieldX<E, X extends XType> on XPtrArrayField<E, X> {
  XLiveList<E, X> live(XPtr? Function() ptrOf, List<E> initial)
    => .ptrArray(ptrOf, this, initial);
}

extension LivePtrFixedArrayFieldX<E, X extends XType> on XPtrValueField<List<E>, XArray<X>> {
  XLiveList<E, X> live(XPtr? Function() ptrOf, List<E> initial)
    => .ptrFixedArray(ptrOf, this, initial);
}

extension LivePtrPtrArrayFieldX<E, X extends XType> on XPtrArrayField<E, XPtrType<X>> {
  XLiveList<XLiveList<E, X>, XPtrType<X>> liveNested(XPtr? Function() ptrOf, List<List<E>> initial)
    => .ptrPtrArray(ptrOf, this, initial);
}

extension LivePtrUnknownSyncFieldX<X extends XTypeUnknownLike> on XPtrValueField<dynamic, X> {
  XLivePtrSync<X> live(XPtr? Function() ptrOf)
    => .ptrSync(ptrOf, this);
}