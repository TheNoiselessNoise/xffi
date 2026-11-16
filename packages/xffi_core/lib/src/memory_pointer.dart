part of '../xffi_core.dart';

/// Backend-agnostic handle to a raw memory buffer returned by a C function.
abstract class XPtr<X extends XType> {

  XPtr get _base => this;

  /// Provides more information on double-frees or reads/writes on an invalid pointer.
  static bool debug = false;

  // ░████████      ░███      ░██████  ░██     ░██ 
  // ░██    ░██    ░██░██    ░██   ░██ ░██    ░██  
  // ░██    ░██   ░██  ░██  ░██        ░██   ░██   
  // ░████████   ░█████████ ░██        ░███████    
  // ░██     ░██ ░██    ░██ ░██        ░██   ░██   
  // ░██     ░██ ░██    ░██  ░██   ░██ ░██    ░██  
  // ░█████████  ░██    ░██   ░██████  ░██     ░██ 

  static XPtr<Y> _defaultFromAddress<Y extends XType>(int address) {
    throw StateError(
      'XPtr.fromAddress called before a memory backend was initialized.'
    );
  }

  /// Creates a new [XPtr] from a given address.
  static XPtr<Y> Function<Y extends XType>(int address) fromAddress = _defaultFromAddress;

  static XPtr<XVoid> _defaultFromBytes(TypedData data) {
    throw StateError(
      'XPtr.fromBytes called before a memory backend was initialized.'
    );
  }

  /// Allocates a new pointer and writes [data] into it.
  /// 
  /// Caller owns the result and must free() it.
  static XPtr<XVoid> Function(TypedData data) fromBytes = _defaultFromBytes;

  /// Allocates a new NUL-terminated UTF-8 C string from [text] and
  /// returns a pointer to it.
  /// 
  /// Caller owns the result and must free() it.
  static XPtr<XChar> Function(String text, [int? bufferSize]) fromString = (text, [bufferSize]) {
    throw StateError(
      'XPtr.fromString called before a memory backend was initialized.'
    );
  };

  static XPtr<Y> _defaultNullptrFactory<Y extends XType>() {
    throw StateError(
      'XPtr.nullptr called before a memory backend was initialized.'
    );
  }

  /// Constructs a nullptr.
  static XPtr<Y> Function<Y extends XType>() nullptr = _defaultNullptrFactory;

  static XPtr<Y> _defaultMalloc<Y extends XType>(int size) {
    throw StateError(
      'XPtr.malloc called before a memory backend was initialized.'
    );
  }

  /// Allocates a memory of given [size].
  static XPtr<Y> Function<Y extends XType>(int size) malloc = _defaultMalloc;

  static XPtr<Y> _defaultCalloc<Y extends XType>(int nmemb, int size) {
    throw StateError(
      'XPtr.calloc called before a memory backend was initialized.'
    );
  }

  /// Allocates a memory of given `nmemb * size` and zero initializes it.
  static XPtr<Y> Function<Y extends XType>(int nmemb, int size) calloc = _defaultCalloc;

  static XPtr<Y> _defaultFactory<Y extends XType>(XPtr src) {
    throw StateError(
      'XPtr.factory called before a memory backend was initialized.'
    );
  }
  
  static XPtr<Y> Function<Y extends XType>(XPtr src) factory = _defaultFactory;

  // ░██████░███     ░███ ░█████████  ░██         
  //   ░██  ░████   ░████ ░██     ░██ ░██         
  //   ░██  ░██░██ ░██░██ ░██     ░██ ░██         
  //   ░██  ░██ ░████ ░██ ░█████████  ░██         
  //   ░██  ░██  ░██  ░██ ░██         ░██         
  //   ░██  ░██       ░██ ░██         ░██         
  // ░██████░██       ░██ ░██         ░██████████ 

  /// The key of the temporary allocation backing this pointer.
  ///
  /// `null` when this pointer is not associated with a tracked temporary
  /// allocation.
  String? allocationKey;

  /// Check if the pointer is a `nullptr`.
  bool get isNull;

  /// Reinterprets this pointer as pointing to [Y] instead of [X].
  ///
  /// Same address/offset, no copy, no runtime check, purely a
  /// compile-time relabeling of what the memory is assumed to contain.
  /// The caller is responsible for [Y] actually matching the underlying data.
  XPtr<Y> cast<Y extends XType>() {
    final ptr = factory<Y>(this);
    ptr.allocationKey ??= allocationKey;
    return ptr;
  }

  /// Copies [length] bytes, viewed as [T].
  /// 
  /// [T] must be a concrete TypedDataList type: Uint8List, Int32List,
  /// Float32List, etc. Throws if [T] isn't one of those.
  T asCopy<T extends TypedDataList>(int length);

  /// Zero-copy view as [T].
  /// 
  /// [T] must be a concrete TypedDataList type: Uint8List, Int32List,
  /// Float32List, etc. Throws if [T] isn't one of those.
  /// 
  /// Invalid after [free]/heap growth.
  T asView<T extends TypedDataList>(int length);

  /// Frees the underlying allocation. Only call this if you
  /// actually own it.
  @mustCallSuper
  void free() => _isFreed = true;

  bool _isFreed = false;

  /// If the underlying allocation has been freed.
  bool get isFreed => _isFreed;

  /// Debug/logging only. Do NOT branch logic on this.
  int get address;

  /// [address] in hexadecimal format.
  String get hex => '0x${address.toRadixString(16).toUpperCase()}';

  /// Same buffer, address advanced by [byteOffset] bytes. Same type [X].
  /// Backends implement via pointer arithmetic (native) or address+offset (wasm).
  XPtr<Y> offsetBy<Y extends XType>(int byteOffset);

  /// Reads [length] bytes at [byteOffset].
  Uint8List readBytes(int byteOffset, int length);

  /// Fills [length] bytes starting at [byteOffset] with the low byte of [value].
  void fillBytes(int value, int length, [int byteOffset = 0]) {
    offsetBy(byteOffset)
      .asView<Uint8List>(length)
      .fillRange(0, length, value & 0xFF);
  }

  /// Bulk-copies [length] bytes from [src] into this pointer.
  void copyBytesFrom(XPtr src, int length, {int destOffset = 0, int srcOffset = 0}) {
    offsetBy(destOffset)
      .asView<Uint8List>(length)
      .setRange(0, length, src.offsetBy(srcOffset).asView<Uint8List>(length));
  }

  /// memcmp-style comparison of [length] bytes.
  int compareBytes(XPtr other, int length, {int offset = 0, int otherOffset = 0}) {
    final a = offsetBy(offset).asView<Uint8List>(length);
    final b = other.offsetBy(otherOffset).asView<Uint8List>(length);
    for (int i = 0; i < length; i++) {
      final diff = a[i] - b[i];
      if (diff != 0) return diff;
    }
    return 0;
  }

  /// Hashes the bytes until [byteSize].
  int computeByteHash(int byteSize, [int byteOffset = 0]) {
    final source = offsetBy(byteOffset);

    // 0x811c9dc5 is the 32-bit FNV offset basis
    var hash = 0x811c9dc5; 
    
    // Read bytes from memory address
    for (var i = 0; i < byteSize; i++) {
      // 0x01000193 is the 32-bit FNV prime
      hash = (hash ^ source.readUint8(i)) * 0x01000193; 
      // Force 32-bit unsigned wrap in Dart VM
      hash &= 0xFFFFFFFF; 
    }
    
    return hash;
  }

  /// Reads a pointer value at `address + byteOffset` and returns it typed as pointing to [Y].
  XPtr<Y> readPtr<Y extends XType>([int byteOffset = 0]);

  /// Writes a pointer at given `address + byteOffset`.
  void writePtr(XPtr? value, [int byteOffset = 0]);

  /// Reads a value of type [XSize] at given `address + byteOffset`.
  int readSize([int byteOffset = 0]) => XType.isNative32Bit ? readUint32(byteOffset) : readUint64(byteOffset);

  /// Reads a value of type [XSsize] at given `address + byteOffset`.
  int readSsize([int byteOffset = 0]) => XType.isNative32Bit ? readInt32(byteOffset) : readInt64(byteOffset);
  
  /// Reads a value of type [XIntPtr] at given `address + byteOffset`.
  int readIntPtr([int byteOffset = 0]) => readSsize(byteOffset);
  
  /// Reads a value of type [XUintPtr] at given `address + byteOffset`.
  int readUintPtr([int byteOffset = 0]) => readSize(byteOffset);

  /// Reads a value of type [XPtrDiff] at given `address + byteOffset`.
  int readPtrDiff([int byteOffset = 0]) => readSsize(byteOffset);

  /// Reads a value of type [XBool] at given `address + byteOffset`.
  bool readBool([int byteOffset = 0]) => readUint8(byteOffset) != 0;

  /// Reads a value of type [XInt8] at given `address + byteOffset`.
  int readInt8([int byteOffset = 0]);

  /// Reads a value of type [XUint8] at given `address + byteOffset`.
  int readUint8([int byteOffset = 0]);
  
  /// Reads a value of type [XInt16] at given `address + byteOffset`.
  int readInt16([int byteOffset = 0]);
  
  /// Reads a value of type [XUint16] at given `address + byteOffset`.
  int readUint16([int byteOffset = 0]);
  
  /// Reads a value of type [XInt32] at given `address + byteOffset`.
  int readInt32([int byteOffset = 0]);
  
  /// Reads a value of type [XUint32] at given `address + byteOffset`.
  int readUint32([int byteOffset = 0]);
  
  /// Reads a value of type [XInt64] at given `address + byteOffset`.
  int readInt64([int byteOffset = 0]);
  
  /// Reads a value of type [XUint64] at given `address + byteOffset`.
  int readUint64([int byteOffset = 0]);
  
  /// Reads a value of type [XFloat32] at given `address + byteOffset`.
  double readFloat32([int byteOffset = 0]);
  
  /// Reads a value of type [XFloat64] at given `address + byteOffset`.
  double readFloat64([int byteOffset = 0]);

  /// Reads a value of type [XChar] at given `address + byteOffset`.
  int readChar([int byteOffset = 0]) => readInt8(byteOffset);

  /// Reads a value of type [XUnsignedChar] at given `address + byteOffset`.
  int readUnsignedChar([int byteOffset = 0]) => readUint8(byteOffset);

  /// Reads a value of type [XShort] at given `address + byteOffset`.
  int readShort([int byteOffset = 0]) => readInt16(byteOffset);

  /// Reads a value of type [XUnsignedShort] at given `address + byteOffset`.
  int readUnsignedShort([int byteOffset = 0]) => readUint16(byteOffset);

  /// Reads a value of type [XInt] at given `address + byteOffset`.
  int readInt([int byteOffset = 0]) => readInt32(byteOffset);

  /// Reads a value of type [XUnsignedInt] at given `address + byteOffset`.
  int readUnsignedInt([int byteOffset = 0]) => readUint32(byteOffset);

  /// Reads a value of type [XFloat] at given `address + byteOffset`.
  double readFloat([int byteOffset = 0]) => readFloat32(byteOffset);

  /// Reads a value of type [XDouble] at given `address + byteOffset`.
  double readDouble([int byteOffset = 0]) => readFloat64(byteOffset);

  /// Reads a value of type [XLong] at given `address + byteOffset`.
  int readLong([int byteOffset = 0]) => XLong.size == 4 ? readInt32(byteOffset) : readInt64(byteOffset);
  
  /// Reads a value of type [XUnsignedLong] at given `address + byteOffset`.
  int readUnsignedLong([int byteOffset = 0]) => XLong.size == 4 ? readUint32(byteOffset) : readUint64(byteOffset);

  /// Reads a value of type [XLongLong] at given `address + byteOffset`.
  int readLongLong([int byteOffset = 0]) => readInt64(byteOffset);
  
  /// Reads a value of type [XUnsignedLongLong] at given `address + byteOffset`.
  int readUnsignedLongLong([int byteOffset = 0]) => readUint64(byteOffset);

  /// Reads a fixed-size char-buffer field as a UTF-8 string, stopping early at NUL if present.
  String readStringUTF8([int? maxLength, int byteOffset = 0])
    => offsetBy(byteOffset).cast<XInt8>().toDartString(maxLength);

  /// Reads a fixed-size char-buffer field as a UTF-16 string, stopping early at NUL if present.
  String readStringUTF16([int? maxLength, int byteOffset = 0])
    => offsetBy(byteOffset).cast<XInt16>().toDartString(maxLength);

  /// Reads a fixed-size char-buffer field as a UTF-32 string, stopping early at NUL if present.
  String readStringUTF32([int? maxLength, int byteOffset = 0])
    => offsetBy(byteOffset).cast<XInt32>().toDartString(maxLength);

  /// Writes a [value] of type [XSize] at given `address + byteOffset`.
  void writeSize(int value, [int byteOffset = 0]) => XType.isNative32Bit ? writeUint32(value, byteOffset) : writeUint64(value, byteOffset);

  /// Writes a [value] of type [XSsize] at given `address + byteOffset`.
  void writeSsize(int value, [int byteOffset = 0]) => XType.isNative32Bit ? writeInt32(value, byteOffset) : writeInt64(value, byteOffset);
  
  /// Writes a [value] of type [XIntPtr] at given `address + byteOffset`.
  void writeIntPtr(int value, [int byteOffset = 0]) => writeSsize(byteOffset);
  
  /// Writes a [value] of type [XUintPtr] at given `address + byteOffset`.
  void writeUintPtr(int value, [int byteOffset = 0]) => writeSize(byteOffset);

  /// Writes a [value] of type [XPtrDiff] at given `address + byteOffset`.
  void writePtrDiff(int value, [int byteOffset = 0]) => writeSsize(byteOffset);

  /// Writes a [value] of type [XBool] at given `address + byteOffset`.
  void writeBool(bool value, [int byteOffset = 0]);

  /// Writes a [value] of type [XInt8] at given `address + byteOffset`.
  void writeInt8(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XUint8] at given `address + byteOffset`.
  void writeUint8(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XInt16] at given `address + byteOffset`.
  void writeInt16(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XUint16] at given `address + byteOffset`.
  void writeUint16(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XInt32] at given `address + byteOffset`.
  void writeInt32(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XUint32] at given `address + byteOffset`.
  void writeUint32(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XInt64] at given `address + byteOffset`.
  void writeInt64(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XUint64] at given `address + byteOffset`.
  void writeUint64(int value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XFloat32] at given `address + byteOffset`.
  void writeFloat32(double value, [int byteOffset = 0]);
  
  /// Writes a [value] of type [XFloat64] at given `address + byteOffset`.
  void writeFloat64(double value, [int byteOffset = 0]);

  /// Writes a [value] of type [XChar] at given `address + byteOffset`.
  void writeChar(int value, [int byteOffset = 0]) => writeInt8(value, byteOffset);

  /// Writes a [value] of type [XUnsignedChar] at given `address + byteOffset`.
  void writeUnsignedChar(int value, [int byteOffset = 0]) => writeUint8(value, byteOffset);

  /// Writes a [value] of type [XShort] at given `address + byteOffset`.
  void writeShort(int value, [int byteOffset = 0]) => writeInt16(value, byteOffset);

  /// Writes a [value] of type [XUnsignedShort] at given `address + byteOffset`.
  void writeUnsignedShort(int value, [int byteOffset = 0]) => writeUint16(value, byteOffset);

  /// Writes a [value] of type [XInt] at given `address + byteOffset`.
  void writeInt(int value, [int byteOffset = 0]) => writeInt32(value, byteOffset);

  /// Writes a [value] of type [XUnsignedInt] at given `address + byteOffset`.
  void writeUnsignedInt(int value, [int byteOffset = 0]) => writeUint32(value, byteOffset);

  /// Writes a [value] of type [XFloat] at given `address + byteOffset`.
  void writeFloat(double value, [int byteOffset = 0]) => writeFloat32(value, byteOffset);

  /// Writes a [value] of type [XDouble] at given `address + byteOffset`.
  void writeDouble(double value, [int byteOffset = 0]) => writeFloat64(value, byteOffset);

  /// Writes a [value] of type [XLong] at given `address + byteOffset`.
  void writeLong(int value, [int byteOffset = 0]) => XLong.size == 4 ? writeInt32(value, byteOffset) : writeInt64(value, byteOffset);
  
  /// Writes a [value] of type [XUnsignedLong] at given `address + byteOffset`.
  void writeUnsignedLong(int value, [int byteOffset = 0]) => XLong.size == 4 ? writeUint32(value, byteOffset) : writeUint64(value, byteOffset);

  /// Writes a [value] of type [XLongLong] at given `address + byteOffset`.
  void writeLongLong(int value, [int byteOffset = 0]) => writeInt64(value, byteOffset);
  
  /// Writes a [value] of type [XUnsignedLongLong] at given `address + byteOffset`.
  void writeUnsignedLongLong(int value, [int byteOffset = 0]) => writeUint64(value, byteOffset);

  /// Writes a UTF-8 [text] into a fixed-size [maxLength]-byte buffer field at
  /// `address + byteOffset`. Truncates if too long; otherwise NUL-terminates
  /// and zero-pads the remainder.
  void writeStringUTF8(String text, [int? maxLength, int byteOffset = 0])
    => offsetBy(byteOffset).cast<XInt8>().writeString(text, maxLength);

  /// Writes a UTF-16 [text] into a fixed-size [maxLength]-byte buffer field at
  /// `address + byteOffset`. Truncates if too long; otherwise NUL-terminates
  /// and zero-pads the remainder.
  void writeStringUTF16(String text, [int? maxLength, int byteOffset = 0])
    => offsetBy(byteOffset).cast<XInt16>().writeString(text, maxLength);

  /// Writes a UTF-32 [text] into a fixed-size [maxLength]-byte buffer field at
  /// `address + byteOffset`. Truncates if too long; otherwise NUL-terminates
  /// and zero-pads the remainder.
  void writeStringUTF32(String text, [int? maxLength, int byteOffset = 0])
    => offsetBy(byteOffset).cast<XInt32>().writeString(text, maxLength);

  /// Byte-offset arithmetic, like `(char*)p + n`.
  XPtr<X> operator +(int bytes) => offsetBy<X>(bytes);
  XPtr<X> operator -(int bytes) => offsetBy<X>(-bytes);
  XPtr<X> operator &(int v) => fromAddress<X>(address & v);

  /// Pointer difference in bytes (not elements, like `(char*)a - (char*)b`).
  int diff(XPtr other) => address - other.address;

  bool operator <(XPtr other)  => address <  other.address;
  bool operator <=(XPtr other) => address <= other.address;
  bool operator >(XPtr other)  => address >  other.address;
  bool operator >=(XPtr other) => address >= other.address;

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is XPtr && address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// A `XPtr<XStructType>` that also knows its element type [X], so it can
/// offer .value/[]/[]= the similar way scalar MemoryType extensions do.
final class XStructPtr<X extends XStruct<X>> extends XPtr<XStructType<X>> {
  final XPtr ptr;
  final XStructDef<X>? _explicitType;

  XStructPtr(this.ptr, [this._explicitType])
    : assert(ptr is! XStructPtr, 'double-wrapped XStructPtr');

  @override
  XPtr get _base => ptr;

  late final XStructDef<X> _structType = _explicitType ?? XStructDefinitions.of<X>();

  /// Returns a live view of the struct backed by this memory.
  ///
  /// The returned struct always retains its memory reference. Field mutations
  /// are therefore written through to the underlying memory immediately.
  X get ref => _structType.factory(op: this);

  /// Returns the current value of the struct.
  ///
  /// If the struct is a literal, the returned value is detached from the
  /// underlying memory and can be mutated independently. Otherwise, its memory
  /// reference is preserved.
  X get value {
    if (!_structType.isValue) return ref;
    return snapshot;
  }

  /// Returns the snapshot value of the struct.
  X get snapshot {
    final value = ref;
    value._op = null;
    value.structReadFrom(this);
    return value;
  }

  /// Copies [v]'s current field values into this memory.
  ///
  /// The identity and memory reference of [ref] are not changed.
  set ref(X v) => _copyOrWrite(ptr, v);

  void _copyOrWrite(XPtr dst, X v) {
    final src = v.op;
    if (src != null) {
      if (src.address == dst.address) return;
      dst.copyBytesFrom(src, _structType.layout.byteSize);
    } else {
      v.structWriteInto(dst);
    }
  }

  X _getAtIndex(int i, {bool view = true}) {
    final off = ptr.offsetBy(i * _structType.layout.byteSize);
    final inner = _structType.ptr(off);
    return view ? inner.ref : inner.value;
  }

  /// Returns a detached copy of the struct at [i].
  ///
  /// Changes made to the returned struct are not written back to memory.
  X operator [](int i) => _getAtIndex(i);
  
  /// Writes the current field values of [v] into the struct at [i].
  ///
  /// This copies the value into memory and does not attach [v] to the
  /// destination memory location.
  void operator []=(int i, X v) => _copyOrWrite(ptr.offsetBy(i * _structType.layout.byteSize), v);

  /// Writes [items] sequentially into the memory referenced by this pointer.
  ///
  /// The number of items written must not exceed the allocated struct array
  /// capacity.
  void writeArray(List<X> items) {
    for (var i = 0; i < items.length; i++) {
      _copyOrWrite(ptr.offsetBy(i * _structType.layout.byteSize), items[i]);
    }
  }

  /// Reads [count] structs sequentially from the memory referenced by this
  /// pointer.
  ///
  /// If [view] is `true`, each returned struct retains a [XStructPtr] to
  /// its corresponding memory location, making it a live memory-backed value.
  ///
  /// If [view] is `false`, each returned struct is a detached copy and does
  /// not retain a pointer to the underlying memory.
  List<X> readArray(int count, {bool view = true}) => .generate(count,
    (i) => _getAtIndex(i, view: view),
  );

  XLiveList<X, XStructType> live({List<X>? initial}) => .live(
    () => ptr,
    readAt: (_, i) => this[i],
    writeAt: (_, i, v) => this[i] = v,
    initial: initial ?? [],
  );

  // XPtr redirection

  @override
  String? get allocationKey => ptr.allocationKey;

  @override
  set allocationKey(String? value) => ptr.allocationKey = value;

  @override
  bool get isNull => ptr.isNull;

  @override
  // ignore: must_call_super
  void free() => ptr.free();

  @override
  int get address => ptr.address;

  @override
  String get hex => ptr.hex;

  @override
  XPtr<Y> cast<Y extends XType>() => ptr.cast();

  @override
  T asCopy<T extends TypedDataList>(int length) => ptr.asCopy<T>(length);

  @override
  T asView<T extends TypedDataList>(int length) => ptr.asView<T>(length);

  @override
  XPtr<Y> offsetBy<Y extends XType>(int byteOffset) => ptr.offsetBy(byteOffset);

  @override
  Uint8List readBytes(int byteOffset, int length) => ptr.readBytes(byteOffset, length);

  @override
  void fillBytes(int value, int length, [int byteOffset = 0]) => ptr.fillBytes(value, length, byteOffset);

  @override
  void copyBytesFrom(XPtr src, int length, {int destOffset = 0, int srcOffset = 0})
    => ptr.copyBytesFrom(src, length, destOffset: destOffset, srcOffset: srcOffset);

  @override
  int compareBytes(XPtr other, int length, {int offset = 0, int otherOffset = 0})
    => ptr.compareBytes(other, length, offset: offset, otherOffset: otherOffset);

  @override
  int computeByteHash(int byteSize, [int byteOffset = 0]) => ptr.computeByteHash(byteSize, byteOffset);

  @override
  XPtr<Y> readPtr<Y extends XType>([int byteOffset = 0]) => ptr.readPtr(byteOffset);

  @override
  void writePtr(XPtr? value, [int byteOffset = 0]) => ptr.writePtr(value, byteOffset);

  @override
  int readSize([int byteOffset = 0]) => ptr.readSize(byteOffset);

  @override
  int readSsize([int byteOffset = 0]) => ptr.readSsize(byteOffset);
  
  @override
  int readIntPtr([int byteOffset = 0]) => ptr.readIntPtr(byteOffset);
  
  @override
  int readUintPtr([int byteOffset = 0]) => ptr.readUintPtr(byteOffset);

  @override
  int readPtrDiff([int byteOffset = 0]) => ptr.readPtrDiff(byteOffset);

  @override
  bool readBool([int byteOffset = 0]) => ptr.readBool(byteOffset);

  @override
  int readInt8([int byteOffset = 0]) => ptr.readInt8(byteOffset);

  @override
  int readUint8([int byteOffset = 0]) => ptr.readUint8(byteOffset);
  
  @override
  int readInt16([int byteOffset = 0]) => ptr.readInt16(byteOffset);
  
  @override
  int readUint16([int byteOffset = 0]) => ptr.readUint16(byteOffset);
  
  @override
  int readInt32([int byteOffset = 0]) => ptr.readInt32(byteOffset);
  
  @override
  int readUint32([int byteOffset = 0]) => ptr.readUint32(byteOffset);
  
  @override
  int readInt64([int byteOffset = 0]) => ptr.readInt64(byteOffset);
  
  @override
  int readUint64([int byteOffset = 0]) => ptr.readUint64(byteOffset);
  
  @override
  double readFloat32([int byteOffset = 0]) => ptr.readFloat32(byteOffset);
  
  @override
  double readFloat64([int byteOffset = 0]) => ptr.readFloat64(byteOffset);

  @override
  int readChar([int byteOffset = 0]) => ptr.readChar(byteOffset);

  @override
  int readUnsignedChar([int byteOffset = 0]) => ptr.readUnsignedChar(byteOffset);

  @override
  int readShort([int byteOffset = 0]) => ptr.readShort(byteOffset);

  @override
  int readUnsignedShort([int byteOffset = 0]) => ptr.readUnsignedShort(byteOffset);

  @override
  int readInt([int byteOffset = 0]) => ptr.readInt(byteOffset);

  @override
  int readUnsignedInt([int byteOffset = 0]) => ptr.readUnsignedInt(byteOffset);

  @override
  double readFloat([int byteOffset = 0]) => ptr.readFloat(byteOffset);

  @override
  double readDouble([int byteOffset = 0]) => ptr.readDouble(byteOffset);

  @override
  int readLong([int byteOffset = 0]) => ptr.readLong(byteOffset);
  
  @override
  int readUnsignedLong([int byteOffset = 0]) => ptr.readUnsignedLong(byteOffset);

  @override
  int readLongLong([int byteOffset = 0]) => ptr.readLongLong(byteOffset);
  
  @override
  int readUnsignedLongLong([int byteOffset = 0]) => ptr.readUnsignedLongLong(byteOffset);

  @override
  String readStringUTF8([int? maxLength, int byteOffset = 0]) => ptr.readStringUTF8(maxLength, byteOffset);

  @override
  String readStringUTF16([int? maxLength, int byteOffset = 0]) => ptr.readStringUTF16(maxLength, byteOffset);

  @override
  String readStringUTF32([int? maxLength, int byteOffset = 0]) => ptr.readStringUTF32(maxLength, byteOffset);

  @override
  void writeSize(int value, [int byteOffset = 0]) => ptr.writeSize(value, byteOffset);

  @override
  void writeSsize(int value, [int byteOffset = 0]) => ptr.writeSsize(value, byteOffset);
  
  @override
  void writeIntPtr(int value, [int byteOffset = 0]) => ptr.writeIntPtr(byteOffset);
  
  @override
  void writeUintPtr(int value, [int byteOffset = 0]) => ptr.writeUintPtr(byteOffset);

  @override
  void writePtrDiff(int value, [int byteOffset = 0]) => ptr.writePtrDiff(byteOffset);

  @override
  void writeBool(bool value, [int byteOffset = 0]) => ptr.writeBool(value, byteOffset);

  @override
  void writeInt8(int value, [int byteOffset = 0]) => ptr.writeInt8(value, byteOffset);
  
  @override
  void writeUint8(int value, [int byteOffset = 0]) => ptr.writeUint8(value, byteOffset);
  
  @override
  void writeInt16(int value, [int byteOffset = 0]) => ptr.writeInt16(value, byteOffset);
  
  @override
  void writeUint16(int value, [int byteOffset = 0]) => ptr.writeUint16(value, byteOffset);
  
  @override
  void writeInt32(int value, [int byteOffset = 0]) => ptr.writeInt32(value, byteOffset);
  
  @override
  void writeUint32(int value, [int byteOffset = 0]) => ptr.writeUint32(value, byteOffset);
  
  @override
  void writeInt64(int value, [int byteOffset = 0]) => ptr.writeInt64(value, byteOffset);
  
  @override
  void writeUint64(int value, [int byteOffset = 0]) => ptr.writeUint64(value, byteOffset);
  
  @override
  void writeFloat32(double value, [int byteOffset = 0]) => ptr.writeFloat32(value, byteOffset);
  
  @override
  void writeFloat64(double value, [int byteOffset = 0]) => ptr.writeFloat64(value, byteOffset);

  @override
  void writeChar(int value, [int byteOffset = 0]) => ptr.writeChar(value, byteOffset);

  @override
  void writeUnsignedChar(int value, [int byteOffset = 0]) => ptr.writeUnsignedChar(value, byteOffset);

  @override
  void writeShort(int value, [int byteOffset = 0]) => ptr.writeShort(value, byteOffset);

  @override
  void writeUnsignedShort(int value, [int byteOffset = 0]) => ptr.writeUnsignedShort(value, byteOffset);

  @override
  void writeInt(int value, [int byteOffset = 0]) => ptr.writeInt(value, byteOffset);

  @override
  void writeUnsignedInt(int value, [int byteOffset = 0]) => ptr.writeUnsignedInt(value, byteOffset);

  @override
  void writeFloat(double value, [int byteOffset = 0]) => ptr.writeFloat(value, byteOffset);

  @override
  void writeDouble(double value, [int byteOffset = 0]) => ptr.writeDouble(value, byteOffset);

  @override
  void writeLong(int value, [int byteOffset = 0]) => ptr.writeLong(value, byteOffset);
  
  @override
  void writeUnsignedLong(int value, [int byteOffset = 0]) => ptr.writeUnsignedLong(value, byteOffset);

  @override
  void writeLongLong(int value, [int byteOffset = 0]) => ptr.writeLongLong(value, byteOffset);
  
  @override
  void writeUnsignedLongLong(int value, [int byteOffset = 0]) => ptr.writeUnsignedLongLong(value, byteOffset);

  @override
  void writeStringUTF8(String text, [int? maxLength, int byteOffset = 0]) => ptr.writeStringUTF8(text, maxLength, byteOffset);

  @override
  void writeStringUTF16(String text, [int? maxLength, int byteOffset = 0]) => ptr.writeStringUTF16(text, maxLength, byteOffset);

  @override
  void writeStringUTF32(String text, [int? maxLength, int byteOffset = 0]) => ptr.writeStringUTF32(text, maxLength, byteOffset);
}