part of '../xffi_core.dart';

sealed class XType {
  const XType();

  static int? _nativeWordSize;

  /// Must be set once by the concrete backend during initialization,
  /// before any MemoryType byteSize/elementByteSize is computed.
  static set nativeWordSize(int value) {
    assert(value == 4 || value == 8, 'unexpected word size: $value');
    _nativeWordSize = value;
  }

  static int get nativeWordSize {
    if (_nativeWordSize == null) {
      throw StateError('MemoryType.nativeWordSize not initialized by backend');
    }

    return _nativeWordSize!;
  }

  /// Whether the native platform has a 32-bit (4-byte) word size.
  static bool get isNative32Bit => nativeWordSize == 4;

  /// Whether the native platform has a 64-bit (8-byte) word size.
  static bool get isNative64Bit => nativeWordSize == 8;

  /// Base type. Underlying unwrapped type.
  XType get baseType => this;

  /// Size of a single element.
  int get byteSize;

  /// Natural alignment for this field, per C rules,
  /// arrays align to their element size, not their total size.
  int get alignment => byteSize;

  /// Reads a value of this [XType] from [p] at byte [offset].
  V? read<V>(XPtr p, int offset);

  /// Writes [value] of this [XType] into [p] at byte [offset].
  void write<V>(XPtr p, int offset, V? value);

  /// Reads the [index]-th element of this [XType] from [p], treating [p] as an
  /// array of elements. The byte offset is `index * byteSize`.
  V? readIndexed<V>(XPtr p, int index)
    => read<V>(p, index * byteSize);

  /// Writes [value] as the [index]-th element of this [XType] into [p], treating
  /// [p] as an array of elements. The byte offset is `index * byteSize`.
  void writeIndexed<V>(XPtr p, int index, V? value)
    => write(p, index * byteSize, value);
}

/// Marker type for scalar-like [XType]s.
mixin XTypeScalarLike on XType {}

/// Marker type for int-like [XType]s.
mixin XTypeIntLike on XTypeScalarLike {

  /// Minimal value of this type.
  int get minValue;

  /// Maximum value of this type.
  int get maxValue;

  /// Raw write of [v] for this type.
  void writeRaw(XPtr p, int offset, int value);

  /// Raw read for this type.
  int readRaw(XPtr p, int offset);

  @override
  V? read<V>(XPtr p, int offset) => readRaw(p, offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value) {
    if (value is int) {
      assert(
        value >= minValue && value <= maxValue,
        'out of range for $runtimeType: $value'
      );
      writeRaw(p, offset, value);
    } else {
      throw ArgumentError.value(value, 'value', 'expected int');
    }
  }
}

abstract class XSignedVarInt extends XType with XTypeScalarLike, XTypeIntLike {
  const XSignedVarInt();

  @override int get byteSize => XType.nativeWordSize;

  @override
  int get minValue => XType.isNative64Bit ? XInt64.min : XInt32.min;
  
  @override
  int get maxValue => XType.isNative64Bit ? XInt64.max : XInt32.max;
  
  @override
  void writeRaw(XPtr p, int offset, int value)
    => XType.isNative64Bit ? p.writeInt64(value, offset) : p.writeInt32(value, offset);
  
  @override
  int readRaw(XPtr p, int offset)
    => XType.isNative64Bit ? p.readInt64(offset) : p.readInt32(offset);
}

abstract class XUnsignedVarInt extends XType with XTypeScalarLike, XTypeIntLike {
  const XUnsignedVarInt();

  @override int get byteSize => XType.nativeWordSize;

  @override
  int get minValue => XType.isNative64Bit ? XInt64.min : 0; // full range on 64-bit

  @override
  int get maxValue => XType.isNative64Bit ? XInt64.max : XUint32.max;

  @override
  void writeRaw(XPtr p, int offset, int value)
    => XType.isNative64Bit ? p.writeUint64(value, offset) : p.writeUint32(value, offset);
  
  @override
  int readRaw(XPtr p, int offset)
    => XType.isNative64Bit ? p.readUint64(offset) : p.readUint32(offset);
}

/// Marker type for double-like [XType]s.
mixin XTypeFloatLike on XTypeScalarLike {}

/// Marker type for unknown-like [XType]s.
mixin XTypeUnknownLike on XType {}

final class XArray<X extends XType> extends XType {
  final X element;
  final int count;

  const XArray(this.element, this.count);

  @override
  XType get baseType => element.baseType;

  @override
  int get byteSize => element.byteSize * count;

  @override
  int get alignment => element.alignment;

  @override
  V? read<V>(XPtr p, int offset)
    => throw UnsupportedError('$this is not directly readable.');

  @override
  void write<V>(XPtr p, int offset, V? value)
    => throw UnsupportedError('$this is not directly writable.');
}

/// Marker type for a `callback/function` pointer.
final class XFunction<F> extends XType {
  String get functionType => F.toString();

  const XFunction();

  @override
  int get byteSize => throw UnsupportedError('$this does not have a known size');

  @override
  V? read<V>(XPtr p, int offset)
    => throw UnsupportedError('$this is not readable');

  @override
  void write<V>(XPtr p, int offset, V? value)
    => throw UnsupportedError('$this is not writable');
}

/// Marker type for a `opaque` type - any type.
final class XOpaque extends XType with XTypeUnknownLike {
  const XOpaque();

  @override
  int get byteSize => throw UnsupportedError('$this does not have a known size');

  @override
  V? read<V>(XPtr p, int offset)
    => throw UnsupportedError('$this is not readable');

  @override
  void write<V>(XPtr p, int offset, V? value)
    => throw UnsupportedError('$this is not writable');
}

/// Marker type for a `void` type - any type.
final class XVoid extends XType with XTypeUnknownLike {
  const XVoid();

  @override
  int get byteSize => throw UnsupportedError('$this does not have a known size');

  @override
  V? read<V>(XPtr p, int offset)
    => throw UnsupportedError('$this is not readable');

  @override
  void write<V>(XPtr p, int offset, V? value)
    => throw UnsupportedError('$this is not writable');
}

/// A raw address into backend memory.
/// 
/// Maps to any C pointer type (`void*`, `Image*`, `unsigned char*`, ...).
final class XPtrType<X extends XType> extends XType {
  final X target;
  
  const XPtrType(this.target);

  static int get size => XType.nativeWordSize;

  @override int get byteSize => size;

  @override
  XType get baseType => target.baseType;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readPtr(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writePtr(value as XPtr?, offset);
}

/// Platform-dependent unsigned integer for object sizes. Maps to C `size_t`.
final class XSize extends XUnsignedVarInt {
  const XSize();

  @override
  V? read<V>(XPtr p, int offset)
    => p.readSize(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeSize((value as num).toInt(), offset);
}

/// Platform-dependent signed integer for object sizes. Maps to C `ssize_t`.
final class XSsize extends XSignedVarInt {
  const XSsize();

  @override
  V? read<V>(XPtr p, int offset)
    => p.readSsize(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeSsize((value as num).toInt(), offset);
}

/// Platform-dependent signed integer capable of holding a pointer. Maps to C `intptr_t`.
final class XIntPtr extends XSignedVarInt {
  const XIntPtr();

  @override
  V? read<V>(XPtr p, int offset)
    => p.readIntPtr(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeIntPtr((value as num).toInt(), offset);
}

/// Platform-dependent unsigned integer capable of holding a pointer. Maps to C `uintptr_t`.
final class XUintPtr extends XUnsignedVarInt {
  const XUintPtr();

  @override
  V? read<V>(XPtr p, int offset)
    => p.readUintPtr(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeUintPtr((value as num).toInt(), offset);
}

/// Platform-dependent signed integer representing the difference between pointers. Maps to C `ptrdiff_t`.
final class XPtrDiff extends XSignedVarInt {
  const XPtrDiff();

  @override
  V? read<V>(XPtr p, int offset)
    => p.readPtrDiff(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writePtrDiff((value as num).toInt(), offset);
}

/// Unsigned 8-bit integer. Maps to C `bool`.
final class XBool extends XType with XTypeScalarLike {
  const XBool();

  static const int size = 1;

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readBool(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value) {
    if (value is bool) {
      p.writeBool(value, offset);
    } else if (value is int) {
      p.writeBool(value != 0, offset);
    } else {
      throw ArgumentError.value(value, 'value', 'expected bool or int');
    }
  }
}

/// Signed 8-bit integer. Maps to C `int8_t`.
final class XInt8 extends XType with XTypeScalarLike, XTypeIntLike {
  const XInt8();

  static const int size = 1;
  static const int min = -128;
  static const int max = 127;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeInt8(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readInt8(offset);
}

/// Unsigned 8-bit integer. Maps to C `uint8_t`.
final class XUint8 extends XType with XTypeScalarLike, XTypeIntLike {
  const XUint8();

  static const int size = 1;
  static const min = 0;
  static const max = 255;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeUint8(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readUint8(offset);
}

/// Signed 16-bit integer. Maps to C `int16_t`.
final class XInt16 extends XType with XTypeScalarLike, XTypeIntLike {
  const XInt16();

  static const int size = 2;
  static const min = -32768;
  static const max = 32767;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeInt16(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readInt16(offset);
}

/// Unsigned 16-bit integer. Maps to C `uint16_t`.
final class XUint16 extends XType with XTypeScalarLike, XTypeIntLike {
  const XUint16();

  static const int size = 2;
  static const min = 0;
  static const max = 65535;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeUint16(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readUint16(offset);
}

/// Signed 32-bit integer. Maps to C `int32_t`.
final class XInt32 extends XType with XTypeScalarLike, XTypeIntLike {
  const XInt32();

  static const int size = 4;
  static const min = -2147483648;
  static const max = 2147483647;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeInt32(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readInt32(offset);
}

/// Unsigned 32-bit integer. Maps to C `uint32_t`.
final class XUint32 extends XType with XTypeScalarLike, XTypeIntLike {
  const XUint32();

  static const int size = 4;
  static const min = 0;
  static const max = 4294967295;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeUint32(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readUint32(offset);
}

/// Signed 64-bit integer. Maps to C `int64_t`.
final class XInt64 extends XType with XTypeScalarLike, XTypeIntLike {
  const XInt64();

  static const int size = 8;
  static const min = -1 << 63;
  static int get max => INT_64_MAX;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeInt64(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readInt64(offset);
}

/// Unsigned 64-bit integer. Maps to C `uint64_t`.
final class XUint64 extends XType with XTypeScalarLike, XTypeIntLike {
  const XUint64();

  static const int size = 8;
  static const min = -1 << 63;
  static int get max => INT_64_MAX;

  @override int get byteSize => size;
  @override int get minValue => min;
  @override int get maxValue => max;
  @override void writeRaw(XPtr p, int offset, int value) => p.writeUint64(value, offset);
  @override int readRaw(XPtr p, int offset) => p.readUint64(offset);
}

/// IEEE-754 single-precision float. Maps to C `float`.
final class XFloat32 extends XType with XTypeScalarLike, XTypeFloatLike {
  const XFloat32();

  static const int size = 4;

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readFloat32(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value) {
    if (value is num) {
      p.writeFloat32(value.toDouble(), offset);
    } else {
      throw ArgumentError.value(value, 'value', 'expected num');
    }
  }
}

/// IEEE-754 double-precision float. Maps to C `double`.
final class XFloat64 extends XType with XTypeScalarLike, XTypeFloatLike {
  const XFloat64();

  static const int size = 8;

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readFloat64(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value) {
    if (value is num) {
      p.writeFloat64(value.toDouble(), offset);
    } else {
      throw ArgumentError.value(value, 'value', 'expected num');
    }
  }
}

/// Platform-dependent signed long integer. Maps to C `long`.
final class XLong extends XSignedVarInt {
  const XLong();

  static int get size => switch (currentMemoryPlatform) {
    .windows => 4,
    _ => XType.nativeWordSize,
  };

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readLong(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeLong((value as num).toInt(), offset);
}

/// Platform-dependent unsigned long integer. Maps to C `unsigned long`.
final class XUnsignedLong extends XUnsignedVarInt {
  const XUnsignedLong();

  static int get size => switch (currentMemoryPlatform) {
    .windows => 4,
    _ => XType.nativeWordSize, 
  };

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readUnsignedLong(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeUnsignedLong((value as num).toInt(), offset);
}

/// Signed 64-bit integer. Maps to C `long long`.
final class XLongLong extends XSignedVarInt {
  const XLongLong();

  static const int size = 8; 

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readLongLong(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeLongLong((value as num).toInt(), offset);
}

/// Unsigned 64-bit integer. Maps to C `unsigned long long`.
final class XUnsignedLongLong extends XUnsignedVarInt {
  const XUnsignedLongLong();

  static const int size = 8; 

  @override
  int get byteSize => size;

  @override
  V? read<V>(XPtr p, int offset)
    => p.readUnsignedLongLong(offset) as V;

  @override
  void write<V>(XPtr p, int offset, V? value)
    => p.writeUnsignedLongLong((value as num).toInt(), offset);
}

final class XString<X extends XTypeIntLike> extends XType {
  final int? maxLength;

  const XString([this.maxLength]);

  Type get unitType => X;

  int lengthOf(String value) => switch (unitType) {
    // Conceptually:
    XInt8 => utf8.encode(value).length,
    XInt16 => value.codeUnits.length,
    XInt32 => value.runes.length,
    _ => throw UnsupportedError("Invalid type $X for measuring length of String."),
  };

  @override
  int get byteSize => (maxLength ?? 1) * switch (X) {
    XInt8 => XInt8.size,
    XInt16 => XInt16.size,
    XInt32 => XInt32.size,
    _ => throw UnsupportedError("Invalid type $X for getting a byteSize."),
  };

  @override
  V? read<V>(XPtr p, int offset) => (switch (unitType) {
    XInt8 => p.offsetBy(offset).cast<XInt8>().toDartString(maxLength),
    XInt16 => p.offsetBy(offset).cast<XInt16>().toDartString(maxLength),
    XInt32 => p.offsetBy(offset).cast<XInt32>().toDartString(maxLength),
    _ => throw UnsupportedError("Invalid type $X for reading a string value."),
  }) as V;

  @override
  void write<V>(XPtr p, int offset, V? value) {
    if (value is! String) throw ArgumentError.value(value, 'value', 'expected String');
    switch (unitType) {
      case XInt8: p.offsetBy(offset).cast<XInt8>().writeString(value, maxLength);
      case XInt16: p.offsetBy(offset).cast<XInt16>().writeString(value, maxLength);
      case XInt32: p.offsetBy(offset).cast<XInt32>().writeString(value, maxLength);
      case _: throw UnsupportedError("Invalid type $X for reading a string value.");
    }
  }
}

/// C `char`. Alias for [XInt8].
typedef XChar = XInt8;

/// C `unsigned char`. Alias for [XUint8].
typedef XUnsignedChar = XUint8;

/// C `short`. Alias for [XInt16].
typedef XShort = XInt16;

/// C `unsigned short`. Alias for [XUint16].
typedef XUnsignedShort = XUint16;

/// C `int`. Alias for [XInt32].
typedef XInt = XInt32;

/// C `unsigned int`. Alias for [XUint32].
typedef XUnsignedInt = XUint32;

/// C `float`. Alias for [XFloat32].
typedef XFloat = XFloat32;

/// C `double`. Alias for [XFloat64].
typedef XDouble = XFloat64;

final class XStructType<X extends XStruct<X>> extends XType {
  final XStructDef<X> struct;

  const XStructType(this.struct);

  @override
  int get byteSize => struct.layout.byteSize;

  @override
  int get alignment => struct.layout.alignment;

  @override
  V? read<V>(XPtr p, int offset) => struct.ptr(p.offsetBy(offset)).ref as V;

  @override
  void write<V>(XPtr p, int offset, V? value) => struct.ptr(p.offsetBy(offset)).ref = value as X;
}

extension XSizePtr on XPtr<XSize> {
  int get value => readSize();
  set value(int v) => writeSize(v);
  int operator [](int i) => readSize(i * XType.nativeWordSize);
  void operator []=(int i, int v) => writeSize(v, i * XType.nativeWordSize);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XBoolPtr on XPtr<XBool> {
  bool get value => readBool();
  set value(bool v) => writeBool(v);
  bool operator [](int i) => readBool(i * XBool.size);
  void operator []=(int i, bool v) => writeBool(v, i * XBool.size);

  List<bool> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<bool> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XPtrArrayOnPtr on XPtr<XPtrType> {
  /// Reads [count] pointers from this pointer array.
  List<XPtr<X>> readPtrArray<X extends XType>(int count)
    => .generate(count, (i) => readPtr(i * XType.nativeWordSize));
}

extension XPtrTypeStringIO on XPtr<XPtrType<XChar>> {
  /// Reads [count] C strings from a `char**`-style pointer (this pointer
  /// points at an array of char* pointers, each read and decoded).
  List<String> readStringArray(int count) {
    if (isNull) return const [];
    return .generate(count, (i) {
      final strPtr = readPtr<XChar>(i * XType.nativeWordSize);
      return strPtr.isNull ? '' : strPtr.toDartString();
    });
  }

  /// Writes [strings] into this pre-allocated char**-sized buffer.
  /// Both the outer array (strings.length pointer slots) and each inner
  /// char* target buffer must already exist. [slotSizes[i]] is the real
  /// allocated byte capacity of slot i's buffer (bytes available,
  /// terminator included), if not provided, string's length is used instead.
  void writeStringArray(List<String> strings, [List<int>? slotSizes]) {
    slotSizes ??= strings.map((s) => s.length).toList();
    assert(strings.length == slotSizes.length);

    for (final (i, s) in strings.indexed) {
      readPtr<XChar>(i * XType.nativeWordSize).writeString(s, slotSizes[i]);
    }
  }
}

extension XInt8Ptr on XPtr<XInt8> {
  int get value => readInt8();
  set value(int v) => writeInt8(v);
  int operator [](int i) => readInt8(i * XInt8.size);
  void operator []=(int i, int v) => writeInt8(v, i * XInt8.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XUtf8StringPtr on XPtr<XInt8> {
  /// Reads a NUL-terminated C string starting at this pointer,
  /// decoded as UTF-8. Scans for the NUL byte itself, no length needed.
  /// 
  /// If [maxLength] is provided reads at most [maxLength] bytes as
  /// a UTF-8 string, stopping early at a NUL byte if found first.
  /// Use when you know a bound (e.g. a fixed-size char buffer) but
  /// the string may be shorter.
  String toDartString([int? maxLength]) => _decodeUtf8(0, maxLength);

  String _decodeUtf8([int startOffset = 0, int? maxLength]) {
    var end = startOffset;
    while (
      (maxLength == null || end - startOffset < maxLength) &&
      readInt8(end) != 0
    ) end++;
    return utf8.decode(readBytes(startOffset, end - startOffset));
  }

  /// Writes [text] into a buffer field at `address`. If
  /// [maxLength] is null, it's derived from the UTF-8 byte length of [text]
  /// (caller is responsible for the field actually being that size).
  /// Truncates if [text] exceeds [maxLength]; otherwise NUL-terminates and
  /// zero-pads the remainder.
  void writeString(String text, [int? maxLength]) {
    final bytes = utf8.encode(text);
    final len = maxLength ?? bytes.length;
    final writeLen = bytes.length < len ? bytes.length : len;
    final dst = asView<Uint8List>(len);
    dst.setRange(0, writeLen, bytes);
    dst.fillRange(writeLen, len, 0);
  }
}

extension XUint8Ptr on XPtr<XUint8> {
  int get value => readUint8();
  set value(int v) => writeUint8(v);
  int operator [](int i) => readUint8(i * XUint8.size);
  void operator []=(int i, int v) => writeUint8(v, i * XUint8.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XInt16Ptr on XPtr<XInt16> {
  int get value => readInt16();
  set value(int v) => writeInt16(v);
  int operator [](int i) => readInt16(i * XInt16.size);
  void operator []=(int i, int v) => writeInt16(v, i * XInt16.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XUtf16StringPtr on XPtr<XInt16> {
  String toDartString([int? maxLength]) => _decodeUtf16(0, maxLength);

  String _decodeUtf16([int startOffset = 0, int? maxLength]) {
    final units = <int>[];
    var byteOffset = startOffset;
    var count = 0;
    while (maxLength == null || count < maxLength) {
      final unit = readUint16(byteOffset);
      if (unit == 0) break;
      units.add(unit);
      byteOffset += 2;
      count++;
    }
    return .fromCharCodes(units);
  }

  /// Writes [text] into a buffer field at `address`. If
  /// [maxLength] is null, it's derived from the UTF-16 code unit length of
  /// [text] (caller is responsible for the field actually being that size).
  ///
  /// [maxLength] is in UTF-16 code units, not bytes. Truncates if [text]
  /// exceeds [maxLength]; otherwise NUL-terminates and zero-pads the
  /// remainder.
  void writeString(String text, [int? maxLength]) {
    var units = text.codeUnits; // List<int>, one per UTF-16 code unit
    var len = maxLength ?? units.length;
    var writeLen = units.length < len ? units.length : len;

    // Don't leave a lone leading surrogate at the truncation boundary.
    if (
      writeLen < units.length &&
      writeLen > 0 && _isHighSurrogate(units[writeLen - 1])
    ) writeLen--;

    final dst = asView<Uint16List>(len);
    dst.setRange(0, writeLen, units);
    dst.fillRange(writeLen, len, 0);
  }

  bool _isHighSurrogate(int u) => u >= 0xD800 && u <= 0xDBFF;
}

extension XUint16Ptr on XPtr<XUint16> {
  int get value => readUint16();
  set value(int v) => writeUint16(v);
  int operator [](int i) => readUint16(i * XUint16.size);
  void operator []=(int i, int v) => writeUint16(v, i * XUint16.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XInt32Ptr on XPtr<XInt32> {
  int get value => readInt32();
  set value(int v) => writeInt32(v);
  int operator [](int i) => readInt32(i * XInt32.size);
  void operator []=(int i, int v) => writeInt32(v, i * XInt32.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XUtf32StringPtr on XPtr<XInt32> {
  String toDartString([int? maxLength]) => _decodeUtf32(0, maxLength);

  String _decodeUtf32([int startOffset = 0, int? maxLength]) {
    final runes = <int>[];
    var byteOffset = startOffset;
    var count = 0;

    while (maxLength == null || count < maxLength) {
      final rune = readUint32(byteOffset);
      if (rune == 0) break;

      runes.add(rune);
      byteOffset += 4;
      count++;
    }

    return .fromCharCodes(runes);
  }

  /// Writes [text] into a buffer field at `address`. If
  /// [maxLength] is null, it's derived from the UTF-32 code unit (rune)
  /// length of [text] (caller is responsible for the field actually being
  /// that size).
  ///
  /// [maxLength] is in UTF-32 code units (runes), not bytes. Truncates if
  /// [text] exceeds [maxLength]; otherwise NUL-terminates and zero-pads the
  /// remainder.
  void writeString(String text, [int? maxLength]) {
    final runes = text.runes.toList(); // full scalar values, no surrogates
    final len = maxLength ?? runes.length;
    final writeLen = runes.length < len ? runes.length : len;
    final dst = asView<Uint32List>(len);
    dst.setRange(0, writeLen, runes);
    dst.fillRange(writeLen, len, 0);
  }
}

extension XUint32Ptr on XPtr<XUint32> {
  int get value => readUint32();
  set value(int v) => writeUint32(v);
  int operator [](int i) => readUint32(i * XUint32.size);
  void operator []=(int i, int v) => writeUint32(v, i * XUint32.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XInt64Ptr on XPtr<XInt64> {
  int get value => readInt64();
  set value(int v) => writeInt64(v);
  int operator [](int i) => readInt64(i * XInt64.size);
  void operator []=(int i, int v) => writeInt64(v, i * XInt64.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XUint64Ptr on XPtr<XUint64> {
  int get value => readUint64();
  set value(int v) => writeUint64(v);
  int operator [](int i) => readUint64(i * XUint64.size);
  void operator []=(int i, int v) => writeUint64(v, i * XUint64.size);

  List<int> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XFloat32Ptr on XPtr<XFloat32> {
  double get value => readFloat32();
  set value(double v) => writeFloat32(v);
  double operator [](int i) => readFloat32(i * XFloat32.size);
  void operator []=(int i, double v) => writeFloat32(v, i * XFloat32.size);

  List<double> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<double> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XFloat64Ptr on XPtr<XFloat64> {
  double get value => readFloat64();
  set value(double v) => writeFloat64(v);
  double operator [](int i) => readFloat64(i * XFloat64.size);
  void operator []=(int i, double v) => writeFloat64(v, i * XFloat64.size);

  List<double> readArray(int count) => .generate(count, (i) => this[i]);

  void writeArray(List<double> values) {
    for (var i = 0; i < values.length; i++) {
      this[i] = values[i];
    }
  }
}

extension XMemoryPtrMatrixIO on XPtr<XPtrType<XStructType>> {
  void writeMatrix<X extends XStruct<X>>(List<List<X>> rows) {
    final type = XStructDefinitions.of<X>();
    for (var i = 0; i < rows.length; i++) {
      type.ptr(readPtr(i * XType.nativeWordSize)).writeArray(rows[i]);
    }
  }

  List<XLiveList<X, XStructType>> readMatrix<X extends XStruct<X>>(
    int rowCount,
    int rowLength, {
    bool materialize = false,
  }) {
    final type = XStructDefinitions.of<X>();
    final List<XLiveList<X, XStructType>> list = .generate(rowCount,
      (i) {
        final live = type.ptr(readPtr(i * XType.nativeWordSize)).live();
        if (materialize) live.materialize(count: rowLength, safe: true);
        return live;
      },
    );
    return list;
  }
}