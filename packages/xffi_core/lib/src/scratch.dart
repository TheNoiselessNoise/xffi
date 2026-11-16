part of '../xffi_core.dart';

/// Pool of preallocated, reusable buffers for short-lived operations that
/// need a temporary [XPtr] without going through a full alloc/free
/// cycle (e.g. binary operations like equality that need scratch space for
/// one call).
///
/// Buffers are stack-allocated in LIFO order via [acquire]/[XScratchHandle.release]:
/// a handle is only valid between its own acquire and release, and must be
/// released before any handle acquired before it. Releasing out of order is
/// a programming error and throws [StateError].
///
/// Lifecycle is tied to the backend, not to this class directly.
///
/// Not instantiatable, use as a static namespace.
final class XScratch {

  XScratch._();

  static final List<XPtr> _buffers = [];
  static final List<int> _sizes = [];
  static int _top = 0;

  /// Frees all backing allocations and empties the pool. Any outstanding
  /// [XScratchHandle] becomes dangling, callers must not hold handles
  /// across a backend lifecycle boundary.
  static void dispose() {
    _buffers.forEach((b) => b.free());
    _buffers.clear();
    _sizes.clear();
    _top = 0;
  }

  /// Claims the next scratch slot on the stack, allocating a new backing
  /// buffer if the stack has never reached this depth before.
  ///
  /// By default the buffer is [XConfig.maxStructByteSize] bytes.
  /// Pass [sizeInBytes] to request more; if the buffer already allocated at
  /// this depth is smaller than [sizeInBytes], it is freed and reallocated
  /// at the larger size before being handed out, this permanently grows
  /// that depth's footprint for subsequent acquires, per the class-level
  /// note on the pool never shrinking. [sizeInBytes] must be positive if
  /// given.
  ///
  /// The returned [XScratchHandle] owns exclusive access to its slot until
  /// [XScratchHandle.release] is called. Handles must be released in
  /// strict LIFO order, release the most recently acquired handle first,
  /// or [XScratchHandle.release] throws [StateError].
  ///
  /// Typical usage:
  /// ```dart
  /// final a = MemoryScratch.acquire();
  /// final b = MemoryScratch.acquire(sizeInBytes: 256);
  /// try {
  ///   // use a.pointer / b.pointer
  /// } finally {
  ///   b.release();
  ///   a.release();
  /// }
  /// ```
  static XScratchHandle<X> acquire<X extends XType>({int? sizeInBytes}) {
    if (sizeInBytes != null && sizeInBytes <= 0) {
      throw ArgumentError.value(sizeInBytes, 'sizeInBytes', 'must be positive');
    }
    final requiredSize = sizeInBytes ?? XConfig.maxStructByteSize;

    if (_top == _buffers.length) {
      _buffers.add(.calloc(1, requiredSize));
      _sizes.add(requiredSize);
    } else if (_sizes[_top] < requiredSize) {
      _buffers[_top].free();
      _buffers[_top] = .calloc(1, requiredSize);
      _sizes[_top] = requiredSize;
    }

    final slot = _top++;
    return XScratchHandle._(slot, _buffers[slot].cast());
  }

  /// Pops [slot] off the stack. Throws [StateError] if [slot] is not
  /// currently the top of the stack, i.e. a more recently acquired handle
  /// has not yet been released.
  static void _release(int slot) {
    if (slot != _top - 1) {
      throw StateError(
        'Scratch buffers released out of order (releasing $slot, top is ${_top - 1}). '
        'Scratch handles must be released LIFO.',
      );
    }
    _top--;
  }
}

/// A live claim on one [XScratch] slot, returned by [XScratch.acquire].
///
/// [ptr] is valid only until [release] is called, and only as long as no
/// handle acquired after this one is still outstanding. Never retain
/// [ptr] beyond that window, and never call [release] more than once
/// per handle (subsequent calls are a no-op).
final class XScratchHandle<X extends XType> {
  final int _slot;

  /// Scratch memory for this claim, cast to [X]. Contents are short-lived
  /// and undefined once [release] is called or a nested [XScratch.acquire]
  /// invalidates the stack ordering guarantee.
  final XPtr<X> ptr;
  bool _released = false;

  XScratchHandle._(this._slot, this.ptr);

  /// Releases this slot back to [XScratch]. Must be called exactly
  /// once, before releasing any handle acquired before this one. Safe to
  /// call from a `finally` block; idempotent on repeat calls.
  void release() {
    if (_released) return;
    _released = true;
    XScratch._release(_slot);
  }
}