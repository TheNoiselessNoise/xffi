part of '../xffi_core.dart';

/// Base for a typed field within a native struct, located at [offset] bytes
/// from the struct's base pointer.
///
/// Subclasses define how a value of type [E] is read from and written to
/// memory, and whether the field needs backing storage allocated.
abstract class XFieldBase<E> {
  /// Byte offset of this field from the start of the struct.
  final int offset;

  const XFieldBase(this.offset);

  /// Reads this field's value from the struct at [p].
  E read(XPtr p);

  /// Like [read], but returns [fallback] if [p] is `null`.
  E readOr(XPtr? p, E fallback) => p == null ? fallback : read(p);

  /// Writes [value] into this field of the struct at [p].
  ///
  /// Returns the value written.
  E write(XPtr p, E value);

  /// Like [write], but does nothing if [p] is `null`.
  ///
  /// Always returns [value], whether or not the write happened.
  E writeOr(XPtr? p, E value) {
    if (p != null) write(p, value);
    return value;
  }

  /// Allocates any backing storage this field needs (e.g. string or array
  /// data that the field points to), using [temp] and identified by [key].
  ///
  /// [p] is the struct base pointer.
  /// 
  /// [count] is the number of elements to allocate for array-like fields.
  /// 
  /// [raw] is used for tracking the allocation (automatic deallocation, no manual free).
  ///
  /// Fields stored inline in the struct have nothing to allocate and no-op.
  void allocate(XPtr p, String key, {int count = 1, bool raw = false});
}

/// A field whose value is stored inline in the struct, read and written via
/// an [XElementCodec].
final class XValueField<E, X extends XType> extends XFieldBase<E> {
  /// Codec used to convert between [E] and its native representation [X].
  final XElementCodec<E, X> codec;

  const XValueField(super.offset, this.codec);

  @override
  E read(XPtr p) => codec.read(p.offsetBy(offset));

  @override
  E write(XPtr p, E value) {
    codec.write(p.offsetBy(offset), value);
    return value;
  }

  @override
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    // no-op
  }
}

/// A pointer-or-array-to-string-value field. Holds a [XStringCodec] concretely.
final class XStringValueField<X extends XTypeIntLike> extends XFieldBase<String> {
  /// Codec used to convert between [String] and its native representation.
  final XStringCodec<X> codec;

  const XStringValueField(super.offset, this.codec);

  @override
  String read(XPtr p)
    => codec.read(p.offsetBy(offset));

  String readBounded(XPtr p, int maxLength)
    => codec.readString(p, maxLength);

  @override
  String write(XPtr p, String value) {
    codec.write(p.offsetBy(offset), value);
    return value;
  }

  @override
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    codec.allocate(p.offsetBy(offset), key, count: count, raw: raw);
  }
}

/// A pointer-to-single-value field. Holds a [XPtrCodec] concretely, no
/// casting, since a pointer field's on-struct type genuinely differs from
/// [XValueField]'s `X` slot (it's `XPtrType<X>`, not `X`).
final class XPtrValueField<E, X extends XType> extends XFieldBase<E> {
  /// Codec used to convert between [E] and the pointed-to native value [X].
  final XPtrCodec<E, X> codec;

  const XPtrValueField(super.offset, this.codec);

  @override
  E read(XPtr p) => codec.read(p.offsetBy(offset));

  @override
  E write(XPtr p, E value) {
    codec.write(p.offsetBy(offset), value);
    return value;
  }

  /// Reads the pointed-to value of this field within the struct at [p].
  ///
  /// Returns [fallback] if the field's pointer is null.
  E readSafe(XPtr p, E fallback)
    => codec.readSafe(p.offsetBy(offset), fallback);

  /// Writes [value] through this field's pointer within the struct at [p].
  ///
  /// Does nothing if the field's pointer is null.
  void writeSafe(XPtr p, E value)
    => codec.writeSafe(p.offsetBy(offset), value);

  @override
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    codec.allocate(p.offsetBy(offset), key, count: count, raw: raw);
  }
}

/// A pointer to a variable-length run of [E], length is runtime-only, so
/// there's no plain `read`/`write`; callers must supply the count they know
/// about externally via [readCount]/[writeCount].
final class XPtrArrayField<E, X extends XType> extends XFieldBase<List<E>> {
  /// Codec used to dereference the field's pointer and convert elements
  /// between [E] and their native representation [X].
  final XPtrCodec<E, X> codec;

  const XPtrArrayField(super.offset, this.codec);

  @override
  List<E> read(XPtr p)
    => throw UnsupportedError('Length is runtime-determined, use `readCount`.');

  @override
  List<E> write(XPtr p, List<E> value)
    => throw UnsupportedError('Length is runtime-determined, use `writeCount`.');

  /// Like [readCount], but returns [fallback] (or an empty list if it is
  /// `null`) when the struct pointer [p] is `null`.
  List<E> readCountOr(XPtr? p, int count, [List<E>? fallback]) {
    if (p == null) return fallback ?? [];
    return readCount(p, count, fallback);
  }

  /// Reads [count] elements from the array this field points to, within the
  /// struct at [p].
  ///
  /// If the field's pointer is null, returns [fallback] (or an empty list if
  /// it is `null`).
  ///
  /// Throws [StateError] if the codec doesn't support contiguous arrays.
  List<E> readCount(XPtr p, int count, [List<E>? fallback]) {
    final ref = codec.deref(p.offsetBy(offset));
    if (ref.isNull) return fallback ?? [];
    return _innerArray().readArray(ref, count);
  }

  /// Writes [values] into the array this field points to, within the struct
  /// at [p]. The pointed-to memory must already be allocated with room for
  /// at least `values.length` elements (see [allocate]).
  ///
  /// Returns [values].
  ///
  /// Throws [StateError] if the codec doesn't support contiguous arrays.
  List<E> writeCount(XPtr p, List<E> values) {
    final ref = codec.deref(p.offsetBy(offset));
    if (ref.isNull) return values;
    _innerArray().writeArray(ref, values);
    return values;
  }

  /// Like [writeCount], but does nothing if the struct pointer [p] is `null`.
  ///
  /// Always returns the given list, whether or not the write happened.
  List<E> writeCountIf(XPtr? p, List<E> values) {
    if (p == null) return values;
    final ref = codec.deref(p.offsetBy(offset));
    _innerArray().writeArray(ref, values);
    return values;
  }

  XContiguousCodec<E, X> _innerArray() {
    final inner = codec.inner;
    if (inner is XContiguousCodec<E, X>) return inner;
    throw StateError(
      '${inner.runtimeType} has no contiguous array support; '
      'index element-by-element via codec.readAt/writeAt instead.',
    );
  }

  @override
  void allocate(XPtr p, String key, {int count = 1, bool raw = false}) {
    codec.allocate(p.offsetBy(offset), key, count: count, raw: raw);
  }
}

final class XLivePtrSync<X extends XType> {
  final XPtr? Function() _ptrOf;
  final int _offset;

  XLivePtrSync._(
    this._ptrOf,
    this._offset
  );

  XPtr<X> fieldPtr() => _ptrOf()?.offsetBy(_offset) ?? .nullptr();

  XPtr<Y> derefPtr<Y extends XType>({
    bool safe = false,
    String dbg = 'Dereferenced a null pointer (no backing memory: detached, unloaded or not yet allocated)',
  }) {
    final base = _ptrOf();
    if (base == null) {
      if (safe) throw StateError('$dbg: struct has no live op');
      return .nullptr<Y>();
    }
    final ptr = base.readPtr<Y>(_offset);
    if (safe && ptr.isNull) throw StateError('$dbg: pointer field is null');
    return ptr;
  }

  factory XLivePtrSync.ptrSync(
    XPtr? Function() ptrOf,
    XPtrValueField<dynamic, X> field,
  ) => ._(ptrOf, field.offset);

  // we don't care about nullptr
  void syncFrom(XPtr p, {bool borrow = true}) {
    if (!borrow) return;
    fieldPtr().writePtr(p.readPtr(_offset));
  }

  void syncInto(XPtr p, {bool safe = true}) {
    final dst = derefPtr();
    if (!dst.isNull) p.writePtr(dst, _offset);
  }
}

extension LivePtrSyncField<E, X extends XType> on XPtrValueField<E, X> {
  XLivePtrSync<X> live(XPtr? Function() ptrOf)
    => .ptrSync(ptrOf, this);
}