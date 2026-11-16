part of '../../xffi_core.dart';

/// Extends [XAlloc] with struct allocation, providing
/// helpers for Dart mirror objects ([X]).
final class XStructAlloc<
  X extends XStruct<X> // Dart mirror object
> extends XArrayAlloc<X, XStructType<X>> {
  /// [XStructDef] for this allocator.
  final XStructDef<X> structType;

  XStructAlloc(this.structType);

  @override
  String get name => '$X';

  @override
  int get byteSize => structType.byteSize;

  @override
  void writeElement(XPtr<XStructType> ptr, int i, X value)
    => value.structWriteInto(ptr.offsetBy(i * byteSize));

  @override
  XStructPtr<X> At(String key, [int count = 1])
    => structType.ptr(super.At(key, count));

  @override
  XStructPtr<X> AtUnique({String? key, int count = 1})
    => structType.ptr(super.AtUnique(key: key, count: count));

  @override
  XStructPtr<X> Raw([int count = 1])
    => structType.ptr(super.Raw(count));

  @override
  XStructPtr<X> RawArray(List<X> array)
    => structType.ptr(super.RawArray(array));

  @override
  XStructPtr<X> Array(List<X> array, {String? key})
    => structType.ptr(super.Array(array, key: key));

  /// Pointer allocator for this struct [X].
  late final XStructPtrAlloc<X> $ = .new(Array, RawArray);

  /// Allocates or syncs [value] to a tracked slot at [key].
  /// 
  /// If [raw] is `true`, make `op` always to be tracked manually (requires manual free).
  /// 
  /// If [unique] is `true`, make `op` always unique no matter the circumstances.
  /// 
  /// Pass [bind] to dictate if the resulting pointer should be bound to the [value].
  XStructPtr<X> Allocate({ X? value, String? key, bool raw = false, bool unique = false, bool? bind }) {
    if (value?.structIsDisposed ?? false) throw StateError('allocating disposed ${value.runtimeType}');
    if (value?.op case final live?) return live;

    key ??= _slotKey();
    final p = raw ? Raw() : unique ? AtUnique(key: key) : At(key);
    if (value == null) return p;

    // allocate any inner/nested pointers (if any)
    value.structAllocateInto(p, p.allocationKey ?? key);

    // write the struct into the given pointer
    value.structWriteInto(p);

    if (bind ?? (raw || unique || !structType.isValue)) value.bind$(p);
    return p;
  }

  XStructPtr<X> _Ref(X? o, String key) {
    if (o == null) return At(key);
    if (!structType.isValue && o.op == null) {
      // own memory, bound
      return Allocate(value: o, unique: true, bind: true);
    }
    // value or already-live, no binding
    return Allocate(value: o, key: key, bind: false);
  }

  /// Allocates [o] to a unique tracked slot or returns `nullptr` if [o] is `null`.
  XStructPtr<X> RefUnique(X? o) => o == null
    ? structType.nullptr()
    : Allocate(value: o, unique: true, bind: true);

  /// Allocates [o] into slot `@ref:1`, or reuses the existing slot `@ref:1` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref1([X? o]) => _Ref(o, '@ref:1');

  /// Allocates [o] into slot `@ref:2`, or reuses the existing slot `@ref:2` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref2([X? o]) => _Ref(o, '@ref:2');

  /// Allocates [o] into slot `@ref:3`, or reuses the existing slot `@ref:3` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref3([X? o]) => _Ref(o, '@ref:3');

  /// Allocates [o] into slot `@ref:4`, or reuses the existing slot `@ref:4` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref4([X? o]) => _Ref(o, '@ref:4');

  /// Allocates [o] into slot `@ref:5`, or reuses the existing slot `@ref:5` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref5([X? o]) => _Ref(o, '@ref:5');

  /// Allocates [o] into slot `@ref:6`, or reuses the existing slot `@ref:6` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref6([X? o]) => _Ref(o, '@ref:6');

  /// Allocates [o] into slot `@ref:7`, or reuses the existing slot `@ref:7` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref7([X? o]) => _Ref(o, '@ref:7');

  /// Allocates [o] into slot `@ref:8`, or reuses the existing slot `@ref:8` allocation
  /// if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> Ref8([X? o]) => _Ref(o, '@ref:8');

  /// Allocates [o] into slot `@ref:1`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull1([X? o]) => o == null ? structType.nullptr() : Ref1(o);

  /// Allocates [o] into slot `@ref:2`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull2([X? o]) => o == null ? structType.nullptr() : Ref2(o);

  /// Allocates [o] into slot `@ref:3`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull3([X? o]) => o == null ? structType.nullptr() : Ref3(o);

  /// Allocates [o] into slot `@ref:4`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull4([X? o]) => o == null ? structType.nullptr() : Ref4(o);

  /// Allocates [o] into slot `@ref:5`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull5([X? o]) => o == null ? structType.nullptr() : Ref5(o);

  /// Allocates [o] into slot `@ref:6`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull6([X? o]) => o == null ? structType.nullptr() : Ref6(o);

  /// Allocates [o] into slot `@ref:7`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull7([X? o]) => o == null ? structType.nullptr() : Ref7(o);

  /// Allocates [o] into slot `@ref:8`, or returns `nullptr` if [o] is `null`.
  ///
  /// Intended as a short-lived scratch reference within a single C call.
  XStructPtr<X> RefOrNull8([X? o]) => o == null ? structType.nullptr() : Ref8(o);

  /// Allocates a uniquely-keyed temporary slot and passes it to [fn].
  ///
  /// The slot is tracked by a unique key of the form `<id>_<key>` and remains
  /// managed by the owning temporary allocator.
  ///
  /// [fn] may either:
  /// - return an [X] containing the result produced by the backend, or
  /// - return `null`/`void` after populating [ptr] with the result.
  X RefCapture(String key, dynamic Function(XStructPtr<X> ptr) fn) {
    final ptr = structType.ptr(AtUnique(key: '@capture:$key'));
    return _getValue(ptr, fn(ptr));
  }

  /// Uses a stable temporary slot identified by [key] and passes it to [fn].
  ///
  /// Unlike [RefCapture], repeated calls with the same [key] reuse the same
  /// temporary backing slot instead of allocating a new uniquely-keyed slot.
  ///
  /// The slot remains managed by the owning temporary allocator and is reused
  /// until the allocator is cleared or disposed.
  ///
  /// [fn] may either:
  /// - return an [X] containing the result produced by the backend, or
  /// - return `null`/`void` after populating [ptr] with the result.
  ///
  /// Use this for APIs whose result can safely share one temporary backing slot
  /// across repeated calls, such as getters returning a current global/default
  /// value. Do not use it when each call must preserve an independent captured
  /// value; use [RefCapture] in that case.
  X RefCached(String key, dynamic Function(XStructPtr<X> ptr) fn) {
    final ptr = Allocate(key: '@cached:$key');
    return _getValue(ptr, fn(ptr));
  }

  X _refresh(XStructPtr<X> ptr, X value) {
    if (value._op == null) {
      value.structWriteInto(ptr);
    } else if (ptr.allocationKey case final key?) {
      value.structAllocateInto(ptr, key);
    }
    value.bind$(ptr);
    return value;
  }

  @visibleForTesting
  X testingExtractResult(XStructPtr<X> ptr, [dynamic result])
    => _getValue(ptr, result);

  X _getValue(XStructPtr<X> ptr, [dynamic result]) {
    if (result is X) {
      if (structType.isValue) {
        // bound result (native toDart): detach to a copy;
        // unbound: as-is
        final op = result._op;
        return op == null ? result : op.value;
      }
      return _refresh(ptr, result);
    }
    if (structType.isValue) return ptr.value;
    return _refresh(ptr, ptr.ref);
  }

  int _extractIndex = 0;
  
  /// Extracts a struct result using temporary slot `@extract:#`.
  ///
  /// [fn] may produce the result in either of two ways, depending on the
  /// backend:
  /// - return an [X] directly, or
  /// - populate [ptr] and return `null`/`void`.
  X Extract(
    dynamic Function(XStructPtr<X> ptr) fn,
  ) {
    _extractIndex++;
    final ptr = At('@extract:$_extractIndex');
    final result = _getValue(ptr, fn(ptr));
    _extractIndex--;
    return result;
  }

  /// Fresh, independently-owned scratch pointer.
  ///
  /// Each access gets its own slot via [AtUnique], keyed with a monotonic id,
  /// so it is safe even when the same call site may be active multiple times
  /// at once (recursion, re-entrant calls).
  XStructPtr<X> get $newPtr => Allocate(key: '@newPtr', unique: true);

  /// [X] view of [$newPtr].
  X get $new => _refresh($newPtr, $newPtr.ref);

  @override
  void dispose() {
    super.dispose();
    $.dispose();
  }
}

/// Extends [XAlloc] with pointer-to-struct allocation,
final class XStructPtrAlloc<
  X extends XStruct<X> // Dart mirror object
> extends XAlloc<XPtrType<XStructType<X>>> {

  /// Converts a [X] of Dart struct wrapper into an allocated [P] pointer.
  final XStructPtr<X> Function(List<X> array, {String? key}) arrayFunc;

  /// Converts a [List] of Dart struct wrappers [X] into an allocated [P] array.
  final XStructPtr<X> Function(List<X> array) rawArrayFunc;

  XStructPtrAlloc(this.arrayFunc, this.rawArrayFunc);

  @override
  String get name => 'XPtrType<$X>';

  @override
  int get byteSize => XType.nativeWordSize;

  /// Writes [array] into a tracked slot of sufficient capacity.
  XPtr<XPtrType<XStructType>> Array(List<List<X>> array, {String? key}) {
    key ??= _slotKey(key);
    final pp = At(key, array.length);
    for (int i = 0; i < array.length; i++) {
      final innerPtr = arrayFunc(array[i], key: '${key}_$i');
      pp.writePtr(innerPtr, i * byteSize);
    }
    return pp;
  }

  /// Allocates an unslotted pointer-of-pointers from a list of struct [arrays].
  ///
  /// The caller is responsible for freeing the returned pointer.
  XPtr<XPtrType<XStructType>> RawArray(List<List<X>> arrays) {
    final pp = Raw(arrays.length);
    for (int i = 0; i < arrays.length; i++) {
      final innerPtr = rawArrayFunc(arrays[i]);
      pp.writePtr(innerPtr, i * byteSize);
    }
    return pp;
  }
}