part of '../xffi_core.dart';

/// Base type for objects backed by native (C-side) struct memory.
abstract class XStruct<X extends XStruct<X>> {
  XStructPtr<X>? _op;
  /// The C-owned or MemoryTemp-owned typed pointer for this struct, if any.
  XStructPtr<X>? get op => _op;

  XStruct({ this._op });

  bool _structIsDisposed = false;
  /// Whether this instance is disposed.
  bool get structIsDisposed => _structIsDisposed;

  // === MUST IMPLEMENT PER-TYPE ===

  /// Copies the fields of [o] into this instance.
  X setDart(X o) => this as X;

  /// Allocates nested pointers into [temp] under [key] as needed.
  void structAllocateInto(XPtr p, String key) {}

  /// Writes the fields into [p].
  void structWriteInto(XPtr p) {}
  
  /// Reads fields from [p].
  void structReadFrom(XPtr p) {}

  // === ====================== ===

  /// Mark this instance as disposed.
  void structDispose() => _structIsDisposed = true;

  /// Bind the [p] to this [XStruct].
  void bind$(XPtr p) => _op = p is XStructPtr<X> ? p : .new(p._base);

  /// Unbind any bound existing pointer from this [XStruct] and return it.
  XStructPtr<X>? unbind$() {
    final p = _op;
    _op = null;
    return p;
  }

  /// Returns [XStructAlloc] for this given [XStruct].
  XStructAlloc<X> alloc$()
    => XTemp.instance.structAlloc<X>();

  /// Allocates or syncs this struct to a tracked slot at [key].
  /// 
  /// See [XStructAlloc.Allocate].
  XStructPtr<X> ptr$({String? key, bool raw = false, bool unique = false, bool bind = false})
    => alloc$().Allocate(value: this as X, key: key, raw: raw, unique: unique, bind: bind);

  /// The Dart-side type name of this struct
  String get structName => runtimeType.toString();

  /// Returns [op], throwing a descriptive [StateError] if unavailable or this instance [structIsDisposed].
  XStructPtr<X> getOp() =>
    _op ?? (throw StateError(structIsDisposed
      ? '$runtimeType: disposed'
      : '$runtimeType: no pointer bound'
    ));

  /// Returns [op] and immediately disposes this struct.
  ///
  /// This is the canonical way to hand a resource-backed struct over to a C API
  /// that takes ownership of the underlying memory.
  @nonVirtual
  XStructPtr<X> getOpAndDispose() {
    final ptr = getOp();
    _structIsDisposed = true;
    _op = null;
    return ptr;
  }

  /// Disposes [struct], invokes [fn] with its underlying pointer, and then frees
  /// the temporary allocation backing the pointer, if any.
  ///
  /// The allocation is freed after [fn] completes, including when [fn] throws.
  /// This is intended for APIs where the external call does not take ownership
  /// of the underlying memory.
  void disposeStructWithOpFreed(void Function(XStructPtr<X> ptr) fn) {
    final ptr = getOpAndDispose();

    try {
      fn(ptr);
    } finally {
      if (ptr.allocationKey case final key?) {
        XTemp.instance.structAlloc<X>().Free(key);
      } else {
        ptr.free();
      }
    }
  }

  /// Disposes [struct], invokes [fn] with its underlying pointer, and then
  /// unslots the temporary allocation backing the pointer, if any.
  ///
  /// The allocation is removed from the temporary allocator without freeing its
  /// underlying memory. This is intended for APIs where the external call takes
  /// responsibility for freeing the memory.
  ///
  /// The allocation is unslotted after [fn] completes, including when [fn]
  /// throws.
  void disposeStructWithOpUnslotted(void Function(XStructPtr<X> ptr) fn) {
    final ptr = getOpAndDispose();

    try {
      fn(ptr);
    } finally {
      if (ptr.allocationKey case final key?) {
        XTemp.instance.structAlloc<X>().Unslot(key);
      }
    }
  }

  /// [XStructDef] for this given struct.
  XStructDef<X> get structType => XStructDefinitions.of<X>();

  /// Returns a deep copy of this instance, preserving [op] if present.
  X clone() => structType.factory(op: op);

  /// Returns a deep copy of this instance without [op].
  ///
  /// Useful when you need an independent value that should not accidentally
  /// sync back into owned memory.
  X copy() {
    if (op case final live?) return live.value;
    final c = structType.factory();
    final scratch = XScratch.acquire(sizeInBytes: structType.byteSize);
    try {
      structWriteInto(scratch.ptr);
      c.structReadFrom(scratch.ptr);
      return c;
    } finally {
      scratch.release();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! X) return false;

    final layout = structType.layout;
    if (layout != other.structType.layout) return false;

    XScratchHandle? sa, sb;

    try {
      XPtr? a = op;
      if (a == null) {
        sa = XScratch.acquire(sizeInBytes: structType.byteSize);
        a = sa.ptr;
        structWriteInto(a);
      }
      
      XPtr? b = other.op;
      if (b == null) {
        sb = XScratch.acquire(sizeInBytes: structType.byteSize);
        b = sb.ptr;
        other.structWriteInto(b);
      }
      
      return a.address == b.address || layout.fieldsEqual(a, b);
    } finally {
      sb?.release();
      sa?.release();
    }
  }

  @override
  int get hashCode {
    final layout = structType.layout;
    final live = op;
    
    if (live != null) return layout.fieldsHash(live);

    final s = XScratch.acquire(sizeInBytes: structType.byteSize);
    try {
      structWriteInto(s.ptr);
      return layout.fieldsHash(s.ptr);
    } finally {
      s.release();
    }
  }

  /// Returns a human-readable representation of this struct.
  String signature() => structName;

  @override
  String toString() => signature();
}

/// Dynamic struct.
final class XDynStruct extends XStruct<XDynStruct> {
  final XStructDef<XDynStruct> _dynType;

  @override @nonVirtual get structType => _dynType;

  Map<String, dynamic> _values;
  
  @nonVirtual
  Map<String, dynamic> get values {
    _values = op == null ? _values : _dynType.peek(_dynType.ptr(op));
    return _values;
  }

  @nonVirtual
  set values(Map<String, dynamic> value) {
    _values = value;
    if (op != null) _dynType.poke(_dynType.ptr(op), value);
  }

  XDynStruct._({
    super.op,
    required this._dynType,
    Map<String, dynamic>? values,
  }) : _values = values ?? {};

  @nonVirtual
  XDynStruct setField(String name, dynamic value) {
    if (!_dynType.layout.fields.containsKey(name)) {
      throw UnsupportedError('Unknown field ${_dynType.typeName}.$name.');
    }
    values = {...values, name: value};
    return this;
  }

  @nonVirtual
  V? getField<V>(String name) {
    final ptr = op;
    return ptr == null ? _values[name] : _dynType.peekField(ptr, name);
  }

  @override
  @nonVirtual
  XDynStruct setDart(XDynStruct o) {
    if (o._dynType != _dynType) throw StateError("Different dynamic type: '${_dynType.typeName}' != '${o._dynType.typeName}'");
    values = .from(o.values);
    return this;
  }

  @override
  @nonVirtual
  void structAllocateInto(XPtr p, String key)
    => _dynType.allocWith(p, values);

  @override
  @nonVirtual
  void structWriteInto(XPtr p)
    => _dynType.poke(_dynType.ptr(p), values);

  @override
  @nonVirtual
  void structReadFrom(XPtr p)
    => values = _dynType.peek(_dynType.ptr(p));
}