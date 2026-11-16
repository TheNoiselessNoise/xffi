part of '../../xffi_core.dart';

/// Base class for memory temporary allocators, managing typed memory slots
/// with a consistent allocation/free lifecycle.
abstract class XAlloc<X extends XType> {
  /// Debug name for this allocator, used in logging and diagnostics.
  late String name;

  /// Size in bytes of a single element this allocator manages.
  int get byteSize;

  Type get _memoryType => X;

  XAlloc() : name = '$X';

  XPtr<XPtrType<Y>> _allocatePointer<Y extends XType>(int count)
    => .calloc(count, XType.nativeWordSize);

  /// Active allocation slots, keyed by slot name.
  /// Each entry holds the pointer and its element count.
  final Map<String, (XPtr<X>, int)> slots = {};

  /// Returns the canonical slot key for [key], falling back to `default`
  /// when [key] is `null`.
  String _slotKey([String? key]) => key ?? 'default';

  /// Returns a slot key guaranteed to be unique within this temp context,
  /// by prefixing [key] with the next available ID.
  String _uniqueSlotKey([String? key]) => '${_slotKey(key)}:${XTemp.instance.nextId()}';

  /// Allocates [count] raw elements and returns the wrapped pointer.
  /// 
  /// The caller is responsible for freeing the returned pointer.
  XPtr<X> Raw([int count = 1]) => .calloc(count, byteSize);

  /// Returns the pointer stored in [key], allocating (or reallocating)
  /// if necessary.
  ///
  /// If the slot already exists and its current capacity is >= [count], the
  /// existing pointer is reused. If capacity is insufficient the old block is
  /// freed and a new one of size [count] is allocated.
  ///
  /// [key]   – slot identifier (must not be null).
  /// [count] – minimum element capacity required (default: 1).
  XPtr<X> At(String key, [int count = 1]) {
    final existing = slots[key];
    if (existing != null) {
      final (ptr, currentCount) = existing;
      if (count <= currentCount) return ptr.cast();
      ptr.free();
    }

    if (slots.length >= XConfig.maxTrackedAllocations) {
      throw StateError(
        'Maximum tracked allocations reached for `$name` (${XConfig.maxTrackedAllocations}). '
        'This may indicate excessive temporary allocation or a bug in '
        '`xffi`. If this limit is legitimately too low for your use case, '
        'increase `MemoryConfig.maxTrackedAllocations` before initializing `Memory`.',
      );
    }

    final ptr = Raw(count);
    ptr.allocationKey = key;
    slots[key] = (ptr, count);
    return ptr;
  }

  /// Allocates (or reuses) a slot identified by a unique [key] suffix.
  ///
  /// Behaves like [At], but prepends a monotonic ID from [XTemp.nextId] to
  /// [key], ensuring the slot is never accidentally shared with an unrelated
  /// call that happens to use the same base key.
  ///
  /// Useful when the same allocation site may be called multiple times within
  /// a single scope and each call must get its own independent buffer.
  XPtr<X> AtUnique({String? key, int count = 1}) => At(_uniqueSlotKey(key), count);

  /// Returns the total byte size for [count] elements.
  int Size([int count = 1]) => byteSize * count;

  /// Returns the pointer stored under [key], or `null` if the slot does not
  /// exist. Does **not** allocate.
  XPtr<X>? Slot(String key) => slots[key]?.$1;

  /// Returns `true` if a slot with the given [key] exists.
  bool Has(String key) => slots.containsKey(key);

  /// Frees the native memory owned by slot [key] and removes it from the
  /// table.
  ///
  /// Throws if [key] has not been allocated.
  void Free(String key) {
    if (!slots.containsKey(key)) throw StateError('[FREE] Cannot free unallocated slot $key');
    XTemp.instance.debugFreeInfo('[FREEing] $key');
    slots.remove(key)!.$1.free();
  }

  /// Removes the slot entry for [key] from the table **without** freeing the
  /// underlying memory.
  ///
  /// Use when ownership of the pointer has been transferred elsewhere.
  void Unslot(String key) => slots.remove(key);

  /// Frees all currently tracked slots and clears the slot table.
  ///
  /// Called automatically by the owning [XTemp] during disposal.
  void dispose() {
    if (slots.isEmpty) return;

    XTemp.instance.debugFreeInfo('Freeing user-defined ${slots.length} $name slots');
    slots.entries.forEach((x) {
      XTemp.instance.debugFreeInfo('[FREE] ${x.key}');
      x.value.$1.free();
    });
    slots.clear();
  }
}

abstract class XArrayAlloc<X, Y extends XType> extends XAlloc<Y> {
  /// Writes [value] into the [i]-th element of the array at [ptr].
  void writeElement(XPtr<Y> ptr, int i, X value) {
    throw UnimplementedError('MemoryTempArrayAllocator.writeElement for $X of type $Y');
  }

  /// Allocates an unslotted array and populates it from [array].
  ///
  /// The caller is responsible for freeing the returned pointer.
  XPtr<Y> RawArray(List<X> array) {
    final p = Raw(array.length);
    for (int i = 0; i < array.length; i++) writeElement(p, i, array[i]);
    return p;
  }

  /// Writes [array] into a slot of sufficient capacity and returns the pointer.
  ///
  /// [key] defaults to `default`. The slot is grown automatically if the
  /// current capacity is smaller than `array.length`.
  XPtr<Y> Array(List<X> array, {String? key}) {
    final p = At(_slotKey(key), array.length);
    for (int i = 0; i < array.length; i++) writeElement(p, i, array[i]);
    return p;
  }
}

/// Dispatches a [TypedDataList] to the correct typed allocator on [temp],
/// allowing callers to allocate any supported typed list without knowing
/// the concrete element type at the call site.
final class XTypedDataListAlloc {
  XTypedDataListAlloc();

  int ElementSize(TypedDataList data) {
    if (data is Int8List) return XTemp.instance.scalarAlloc<XInt8>().byteSize;
    if (data is Uint8List) return XTemp.instance.scalarAlloc<XUint8>().byteSize;
    if (data is Int16List) return XTemp.instance.scalarAlloc<XInt16>().byteSize;
    if (data is Uint16List) return XTemp.instance.scalarAlloc<XUint16>().byteSize;
    if (data is Int32List) return XTemp.instance.scalarAlloc<XInt32>().byteSize;
    if (data is Uint32List) return XTemp.instance.scalarAlloc<XUint32>().byteSize;
    if (data is Int64List) return XTemp.instance.scalarAlloc<XInt64>().byteSize;
    if (data is Uint64List) return XTemp.instance.scalarAlloc<XUint64>().byteSize;
    if (data is Float32List) return XTemp.instance.scalarAlloc<XFloat32>().byteSize;
    if (data is Float64List) return XTemp.instance.scalarAlloc<XFloat64>().byteSize;
    throw UnimplementedError('ElementSize: Unknown typed list: ${data.runtimeType}');
  }

  XPtr<XVoid> Array(TypedDataList data, {String? key}) {
    if (data is Int8List) return XTemp.instance.scalarAlloc<XInt8>().Array(data, key: key).cast();
    if (data is Uint8List) return XTemp.instance.scalarAlloc<XUint8>().Array(data, key: key).cast();
    if (data is Int16List) return XTemp.instance.scalarAlloc<XInt16>().Array(data, key: key).cast();
    if (data is Uint16List) return XTemp.instance.scalarAlloc<XUint16>().Array(data, key: key).cast();
    if (data is Int32List) return XTemp.instance.scalarAlloc<XInt32>().Array(data, key: key).cast();
    if (data is Uint32List) return XTemp.instance.scalarAlloc<XUint32>().Array(data, key: key).cast();
    if (data is Int64List) return XTemp.instance.scalarAlloc<XInt64>().Array(data, key: key).cast();
    if (data is Uint64List) return XTemp.instance.scalarAlloc<XUint64>().Array(data, key: key).cast();
    if (data is Float32List) return XTemp.instance.scalarAlloc<XFloat32>().Array(data, key: key).cast();
    if (data is Float64List) return XTemp.instance.scalarAlloc<XFloat64>().Array(data, key: key).cast();
    throw UnimplementedError('Array: Unknown typed list: ${data.runtimeType}');
  }
}