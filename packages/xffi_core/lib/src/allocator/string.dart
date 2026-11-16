part of '../../xffi_core.dart';

typedef _PtrArray = ({XPtr<XPtrType<XChar>> ptr, int capacity});

final class _StringSlot {
  XPtr<XChar> ptr = .nullptr();
  int capacity = 0;

  void free() {
    if (!ptr.isNull) ptr.free();
    ptr = .nullptr();
    capacity = 0;
  }
}

/// Extends [XAlloc] with string allocation, handling
/// UTF-8 encoding and null-termination into temporary slots.
///
/// A pointer returned for a slot is only valid until the next write to that
/// slot: a longer string reallocates it.
final class XStringAlloc extends XAlloc<XChar> {
  XStringAlloc() { reset(); }

  /// Number of anonymous (ring-buffer) slots. Read on construction and [reset].
  int get slotCount => XConfig.tempStringSlots;

  @override
  int get byteSize => XChar.size;

  @override
  String get name => 'String';

  late List<_StringSlot> _ring;
  int _ringIndex = 0;
  final Map<String, _StringSlot> _keyed = {};
  final Map<String, _PtrArray> _ptrArrays = {};

  void reset() {
    _ring = List.generate(slotCount, (_) => _StringSlot(), growable: false);
    _ringIndex = 0;
    _keyed.clear();
    _ptrArrays.clear();
  }

  /// Encodes [text] into [slot] (NUL-terminated, zero-padded up to
  /// [bufferSize]), growing the slot if needed.
  XPtr<XChar> _write(_StringSlot slot, String text, int? bufferSize) {
    final bytes = utf8.encode(text);
    final minSize = bytes.length + 1; // +1 for NUL
    final size = (bufferSize != null && bufferSize > minSize) ? bufferSize : minSize;

    if (slot.capacity < size) {
      slot.free();
      slot.ptr = Raw(size);
      slot.capacity = size;
    }

    slot.ptr.asView<Uint8List>(size)
      ..setAll(0, bytes)
      ..fillRange(bytes.length, size, 0);

    return slot.ptr;
  }

  /// Returns an untracked NUL-terminated copy of [text].
  ///
  /// The caller is responsible for freeing the returned pointer.
  XPtr<XChar> RawValue(String text, [int? bufferSize]) {
    final bytes = utf8.encode(text);
    final minSize = bytes.length + 1;
    final size = (bufferSize != null && bufferSize > minSize) ? bufferSize : minSize;

    final XPtr<XChar> ptr = .calloc(size, XChar.size); // zeroed
    ptr.asView<Uint8List>(size).setAll(0, bytes);
    return ptr;
  }

  /// Returns the pointer for [text] using the next anonymous ring-buffer slot.
  ///
  /// Anonymous slots cycle modulo [slotCount], so older anonymous strings
  /// may be overwritten. If [key] is provided, delegates to [ValueAt].
  XPtr<XChar> Value(String text, [String? key, int? bufferSize]) {
    if (key != null) return ValueAt(key, text, bufferSize);
    final slot = _ring[_ringIndex];
    _ringIndex = (_ringIndex + 1) % _ring.length;
    return _write(slot, text, bufferSize);
  }

  /// Like [Value], but returns `nullptr` if [text] is `null`.
  ///
  /// Use when the C API uses a null pointer to signal "no value".
  XPtr<XChar> ValueOrNull(String? text, [String? key, int? bufferSize])
    => text == null ? .nullptr() : Value(text, key, bufferSize);

  /// Returns the pointer for the keyed slot [key], optionally writing [text].
  ///
  /// If [text] is `null`, returns the existing string; asserts that the slot
  /// was initialised at least once.
  XPtr<XChar> ValueAt(String key, [String? text, int? bufferSize]) {
    final slot = _keyed[key] ??= _StringSlot();
    if (text != null) return _write(slot, text, bufferSize);

    assert(!slot.ptr.isNull, '[TEMP] String.ValueAt("$key") used before initialization');
    return slot.ptr;
  }

  /// Keyed pointer array of at least [count] `char*` entries.
  ///
  /// Capacity only grows, so a smaller request keeps the existing pointer.
  XPtr<XPtrType<XChar>> AtPtr(String key, [int count = 1]) {
    final existing = _ptrArrays[key];
    if (existing != null && existing.capacity >= count) return existing.ptr;

    existing?.ptr.free();
    final ptr = _allocatePointer<XChar>(count)..allocationKey = key;
    _ptrArrays[key] = (ptr: ptr, capacity: count);
    return ptr;
  }

  /// Writes each string in [array] into keyed sub-slots (`<key>_<i>`) and
  /// returns a tracked pointer array of length `array.length`.
  XPtr<XPtrType<XChar>> Array(List<String> array, {String? key}) {
    final arrayKey = _slotKey(key);
    final pp = AtPtr(arrayKey, array.length);
    for (var i = 0; i < array.length; i++) {
      final sp = ValueAt('${arrayKey}_$i', array[i]);
      pp.writePtr(sp, i * XType.nativeWordSize);
    }
    return pp;
  }

  @override
  void Free(String key) {
    final slot = _keyed.remove(key) ?? (throw StateError('[FREE] Cannot free unallocated String slot $key'));
    slot.free();
  }

  @override
  void dispose() {
    XTemp.instance.debugFreeInfo('Freeing preallocated ${_ring.length} $name slots');
    for (final slot in _ring) slot.free();

    if (_keyed.isNotEmpty) {
      XTemp.instance.debugFreeInfo('Freeing user-defined ${_keyed.length} $name slots');
      for (final MapEntry(:key, value: slot) in _keyed.entries) {
        if (slot.ptr.isNull) continue;
        XTemp.instance.debugFreeInfo('[FREE] $key');
        slot.free();
      }
    }

    if (_ptrArrays.isNotEmpty) {
      XTemp.instance.debugFreeInfo('Freeing user-defined ${_ptrArrays.length} $name Array slots');
      for (final MapEntry(:key, :value) in _ptrArrays.entries) {
        XTemp.instance.debugFreeInfo('[FREE] $key');
        value.ptr.free();
      }
    }

    reset();
  }

  /// Writes [o] into slot `@ref:1` and returns its pointer.
  ///
  /// Use [RefOrNull1] if [o] may be `null` and the callee expects `nullptr` in that case.
  XPtr<XChar> Ref1([String? o, int? bufferSize]) => ValueAt('@ref:1', o, bufferSize);

  /// Writes [o] into slot `@ref:2` and returns its pointer.
  ///
  /// Use [RefOrNull2] if [o] may be `null` and the callee expects `nullptr` in that case.
  XPtr<XChar> Ref2([String? o, int? bufferSize]) => ValueAt('@ref:2', o, bufferSize);

  /// Writes [o] into slot `@ref:3` and returns its pointer.
  ///
  /// Use [RefOrNull3] if [o] may be `null` and the callee expects `nullptr` in that case.
  XPtr<XChar> Ref3([String? o, int? bufferSize]) => ValueAt('@ref:3', o, bufferSize);

  /// Writes [o] into slot `@ref:4` and returns its pointer.
  ///
  /// Use [RefOrNull4] if [o] may be `null` and the callee expects `nullptr` in that case.
  XPtr<XChar> Ref4([String? o, int? bufferSize]) => ValueAt('@ref:4', o, bufferSize);

  /// Writes [o] into slot `@ref:1` and returns its pointer, or returns `nullptr` if [o] is `null`.
  ///
  /// Use this instead of [Ref1] when the C API uses a null pointer to signal "no value".
  XPtr<XChar> RefOrNull1(String? o, [int? bufferSize]) => o == null ? .nullptr() : Ref1(o, bufferSize);

  /// Writes [o] into slot `@ref:2` and returns its pointer, or returns `nullptr` if [o] is `null`.
  ///
  /// Use this instead of [Ref2] when the C API uses a null pointer to signal "no value".
  XPtr<XChar> RefOrNull2(String? o, [int? bufferSize]) => o == null ? .nullptr() : Ref2(o, bufferSize);

  /// Writes [o] into slot `@ref:3` and returns its pointer, or returns `nullptr` if [o] is `null`.
  ///
  /// Use this instead of [Ref3] when the C API uses a null pointer to signal "no value".
  XPtr<XChar> RefOrNull3(String? o, [int? bufferSize]) => o == null ? .nullptr() : Ref3(o, bufferSize);

  /// Writes [o] into slot `@ref:4` and returns its pointer, or returns `nullptr` if [o] is `null`.
  ///
  /// Use this instead of [Ref4] when the C API uses a null pointer to signal "no value".
  XPtr<XChar> RefOrNull4(String? o, [int? bufferSize]) => o == null ? .nullptr() : Ref4(o, bufferSize);
}