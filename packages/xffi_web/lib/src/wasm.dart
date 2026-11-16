part of '../xffi_web.dart';

typedef Reader<T> = T Function(ByteData d, int byteOffset);
typedef Writer<T> = void Function(ByteData d, int byteOffset, T v);

final class WasmType<T extends Object> {
  final int size;
  final Reader<T> read;
  final Writer<T> write;
  const WasmType(this.size, this.read, this.write);
}

final class WasmTypes {
  static final Int8    = WasmType<int>(1, (d, o) => d.getInt8(o),   (d, o, v) => d.setInt8(o, v));
  static final Uint8   = WasmType<int>(1, (d, o) => d.getUint8(o),  (d, o, v) => d.setUint8(o, v));
  static final Int16   = WasmType<int>(2, (d, o) => d.getInt16(o, Endian.little),  (d, o, v) => d.setInt16(o, v, Endian.little));
  static final Uint16  = WasmType<int>(2, (d, o) => d.getUint16(o, Endian.little), (d, o, v) => d.setUint16(o, v, Endian.little));
  static final Int32   = WasmType<int>(4, (d, o) => d.getInt32(o, Endian.little),  (d, o, v) => d.setInt32(o, v, Endian.little));
  static final Uint32  = WasmType<int>(4, (d, o) => d.getUint32(o, Endian.little), (d, o, v) => d.setUint32(o, v, Endian.little));
  static final Float32 = WasmType<double>(4, (d, o) => d.getFloat32(o, Endian.little), (d, o, v) => d.setFloat32(o, v, Endian.little));
  static final Float64 = WasmType<double>(8, (d, o) => d.getFloat64(o, Endian.little), (d, o, v) => d.setFloat64(o, v, Endian.little));

  // 64-bit: split into two 32-bit halves (little-endian: low word first)
  static final Int64 = WasmType<int>(8,
    (d, o) {
      final lo = d.getUint32(o, Endian.little);
      final hi = d.getInt32(o + 4, Endian.little);    // signed high word
      return hi * 0x100000000 + lo;                   // exact only within ±2^53
    },
    (d, o, v) {
      d.setUint32(o, v % 0x100000000, Endian.little); // floor-mod -> non-negative
      d.setInt32(o + 4, (v / 0x100000000).floor(), Endian.little);
    },
  );
  static final Uint64 = WasmType<int>(8,
    (d, o) => d.getUint32(o + 4, Endian.little) * 0x100000000 + d.getUint32(o, Endian.little),
    (d, o, v) {
      d.setUint32(o, v % 0x100000000, Endian.little);
      d.setUint32(o + 4, v ~/ 0x100000000, Endian.little);
    },
  );

  // C-name aliases share the same underlying descriptor
  static final Char = Int8, UnsignedChar = Uint8;
  static final Short = Int16, UnsignedShort = Uint16;
  static final Int = Int32, UnsignedInt = Uint32;
  static final Float = Float32, Double = Float64;

  static final Long             = XType.isNative32Bit ? Int32  : Int64;
  static final UnsignedLong     = XType.isNative32Bit ? Uint32 : Uint64;
  static final LongLong         = Int64;
  static final UnsignedLongLong = Uint64;

  static final Size     = XType.isNative32Bit ? Uint32 : Uint64;
  static final Ssize    = XType.isNative32Bit ? Int32  : Int64;
  static final UintPtr  = Size;
  static final IntPtr   = Ssize;
  static final PtrDiff  = Ssize;
}

final class WasmSize {
  static const int Bool             = Uint8;
  static const int Int8             = 1;
  static const int Uint8            = 1;
  static const int Int16            = 2;
  static const int Uint16           = 2;
  static const int Int32            = 4;
  static const int Uint32           = 4;
  static const int Int64            = 8;
  static const int Uint64           = 8;
  static const int Float32          = 4;
  static const int Float64          = 8;
  static const int Char             = Int8;
  static const int UnsignedChar     = Uint8;
  static const int Short            = Int16;
  static const int UnsignedShort    = Uint16;
  static const int Int              = Int32;
  static const int UnsignedInt      = Uint32;
  static const int Float            = Float32;
  static const int Double           = Float64;
  static int get Long               => XType.isNative32Bit ? Int32  : Int64;
  static int get UnsignedLong       => XType.isNative32Bit ? Uint32 : Uint64;
  static const int LongLong         = Int64;
  static const int UnsignedLongLong = Uint64;
  static int get Size               => XType.isNative32Bit ? Uint32 : Uint64;
  static int get Ssize              => XType.isNative32Bit ? Int32  : Int64;
  static int get UintPtr            => Size;
  static int get IntPtr             => Ssize;
  static int get PtrDiff            => Ssize;
}

final class WasmMemory {
  static ByteData Function() view = () => throw UnimplementedError('WasmMemory.view');

  static int _elemSize(Type t) => switch (t) {
    const (Uint8List) || const (Int8List) => 1,
    const (Uint16List) || const (Int16List) => 2,
    const (Uint32List) || const (Int32List) || const (Float32List) => 4,
    const (Float64List) => 8,
    _ => throw UnsupportedError('WasmMemory: $t not supported (dart2js has no 64-bit int lists)'),
  };

  static T asView<T extends TypedDataList>([int? address, int? length]) {
    _elemSize(T); // throws on unsupported types
    final v = WasmMemory.view();
    final b = v.buffer;
    final o = (address ?? 0) + v.offsetInBytes;
    return switch (T) {
      const (Uint8List)   => b.asUint8List(o, length) as T,
      const (Int8List)    => b.asInt8List(o, length) as T,
      const (Uint16List)  => b.asUint16List(o, length) as T,
      const (Int16List)   => b.asInt16List(o, length) as T,
      const (Uint32List)  => b.asUint32List(o, length) as T,
      const (Int32List)   => b.asInt32List(o, length) as T,
      const (Float32List) => b.asFloat32List(o, length) as T,
      const (Float64List) => b.asFloat64List(o, length) as T,
      _ => throw UnsupportedError('WasmMemory.asView<$T> not implemented'),
    };
  }

  static int Function(int size) malloc = (int size) => throw UnimplementedError('WasmMemory.malloc');
  static int Function(int nmemb, int size) calloc = (int nmemb, int size) => throw UnimplementedError('WasmMemory.calloc');
  static void Function(int ptr) free = (int ptr) => throw UnimplementedError('WasmMemory.free');
  static int Function(int ptr, int value, int num) memset = (int ptr, int value, int num) => throw UnimplementedError('WasmMemory.memset');
  static void Function(String str, int ptr, int maxLen) stringToUTF8 = (String str, int ptr, int maxLen) => throw UnimplementedError('WasmMemory.stringToUTF8');
  static int Function(String str) lengthBytesUTF8 = (String str) => throw UnimplementedError('WasmMemory.lengthBytesUTF8');
  static int Function(JSFunction func, String signature) addFunction = (func, signature) => throw UnimplementedError('WasmMemory.addFunction');
  static void Function(int index) removeFunction = (index) => throw UnimplementedError('WasmMemory.removeFunction');

  // wrap

  /// normal wrapping
  static JSFunction Function(String name, int arity) wrap = (name, arity) => throw UnimplementedError('WasmMemory.wrap');

  /// sret wrapping
  static JSFunction Function(String name, int arity) swrap = (name, arity) => throw UnimplementedError('WasmMemory.swrap');

  static XWasmPtr<X> _defaultSymbol<X extends XType>(String name) => throw UnimplementedError('WasmMemory.symbol');

  /// Resolves a global symbol exported by the WASM module and wraps its
  /// address as a [XWasmPtr].
  ///
  /// `name` is the C symbol name.
  /// `X` is a marker only.
  ///
  /// Use this for global variables/constants exported by the module.
  static XWasmPtr<X> Function<X extends XType>(String name) symbol = _defaultSymbol;

  // read/write

  static void write<T extends Object>(WasmType<T> t, int ptr, T value, [int offset = 0])
    => t.write(view(), ptr + offset, value);

  static T read<T extends Object>(WasmType<T> t, int ptr, [int offset = 0])
    => t.read(view(), ptr + offset);

  static int readPtr(int ptr, [int offset = 0]) => readUint32(ptr, offset);
  static int readSize(int ptr, [int offset = 0]) => XType.isNative32Bit ? readUint32(ptr, offset) : readUint64(ptr, offset);
  static bool readBool(int ptr, [int offset = 0]) => read<int>(WasmTypes.Uint8, ptr, offset) != 0;
  static int readInt8(int ptr, [int offset = 0]) => read(WasmTypes.Int8, ptr, offset);
  static int readUint8(int ptr, [int offset = 0]) => read(WasmTypes.Uint8, ptr, offset);
  static int readInt16(int ptr, [int offset = 0]) => read(WasmTypes.Int16, ptr, offset);
  static int readUint16(int ptr, [int offset = 0]) => read(WasmTypes.Uint16, ptr, offset);
  static int readInt32(int ptr, [int offset = 0]) => read(WasmTypes.Int32, ptr, offset);
  static int readUint32(int ptr, [int offset = 0]) => read(WasmTypes.Uint32, ptr, offset);
  static int readInt64(int ptr, [int offset = 0]) => read(WasmTypes.Int64, ptr, offset);
  static int readUint64(int ptr, [int offset = 0]) => read(WasmTypes.Uint64, ptr, offset);
  static double readFloat32(int ptr, [int offset = 0]) => read(WasmTypes.Float32, ptr, offset);
  static double readFloat64(int ptr, [int offset = 0]) => read(WasmTypes.Float64, ptr, offset);
  static int readChar(int ptr, [int offset = 0]) => read(WasmTypes.Char, ptr, offset);
  static int readUnsignedChar(int ptr, [int offset = 0]) => read(WasmTypes.UnsignedChar, ptr, offset);
  static int readShort(int ptr, [int offset = 0]) => read(WasmTypes.Short, ptr, offset);
  static int readUnsignedShort(int ptr, [int offset = 0]) => read(WasmTypes.UnsignedShort, ptr, offset);
  static int readInt(int ptr, [int offset = 0]) => read(WasmTypes.Int, ptr, offset);
  static int readUnsignedInt(int ptr, [int offset = 0]) => read(WasmTypes.UnsignedInt, ptr, offset);
  static double readFloat(int ptr, [int offset = 0]) => read(WasmTypes.Float, ptr, offset);
  static double readDouble(int ptr, [int offset = 0]) => read(WasmTypes.Double, ptr, offset);
  static int readLong(int ptr, [int offset = 0]) => read(WasmTypes.Long, ptr, offset);
  static int readUnsignedLong(int ptr, [int offset = 0]) => read(WasmTypes.UnsignedLong, ptr, offset);
  static int readLongLong(int ptr, [int offset = 0]) => read(WasmTypes.LongLong, ptr, offset);
  static int readUnsignedLongLong(int ptr, [int offset = 0]) => read(WasmTypes.UnsignedLongLong, ptr, offset);

  static void writePtr(int ptr, int value, [int offset = 0]) => writeUint32(ptr, value, offset);
  static void writeSize(int ptr, int value, [int offset = 0]) => XType.isNative32Bit ? writeUint32(ptr, value, offset) : writeUint64(ptr, value, offset);
  static void writeBool(int ptr, bool value, [int offset = 0]) => write<int>(WasmTypes.Uint8, ptr, value ? 1 : 0, offset);
  static void writeInt8(int ptr, int value, [int offset = 0]) => write(WasmTypes.Int8, ptr, value, offset);
  static void writeUint8(int ptr, int value, [int offset = 0]) => write(WasmTypes.Uint8, ptr, value, offset);
  static void writeInt16(int ptr, int value, [int offset = 0]) => write(WasmTypes.Int16, ptr, value, offset);
  static void writeUint16(int ptr, int value, [int offset = 0]) => write(WasmTypes.Uint16, ptr, value, offset);
  static void writeInt32(int ptr, int value, [int offset = 0]) => write(WasmTypes.Int32, ptr, value, offset);
  static void writeUint32(int ptr, int value, [int offset = 0]) => write(WasmTypes.Uint32, ptr, value, offset);
  static void writeInt64(int ptr, int value, [int offset = 0]) => write(WasmTypes.Int64, ptr, value, offset);
  static void writeUint64(int ptr, int value, [int offset = 0]) => write(WasmTypes.Uint64, ptr, value, offset);
  static void writeFloat32(int ptr, double value, [int offset = 0]) => write(WasmTypes.Float32, ptr, value, offset);
  static void writeFloat64(int ptr, double value, [int offset = 0]) => write(WasmTypes.Float64, ptr, value, offset);
  static void writeChar(int ptr, int value, [int offset = 0]) => write(WasmTypes.Char, ptr, value, offset);
  static void writeUnsignedChar(int ptr, int value, [int offset = 0]) => write(WasmTypes.UnsignedChar, ptr, value, offset);
  static void writeShort(int ptr, int value, [int offset = 0]) => write(WasmTypes.Short, ptr, value, offset);
  static void writeUnsignedShort(int ptr, int value, [int offset = 0]) => write(WasmTypes.UnsignedShort, ptr, value, offset);
  static void writeInt(int ptr, int value, [int offset = 0]) => write(WasmTypes.Int, ptr, value, offset);
  static void writeUnsignedInt(int ptr, int value, [int offset = 0]) => write(WasmTypes.UnsignedInt, ptr, value, offset);
  static void writeFloat(int ptr, double value, [int offset = 0]) => write(WasmTypes.Float, ptr, value, offset);
  static void writeDouble(int ptr, double value, [int offset = 0]) => write(WasmTypes.Double, ptr, value, offset);
  static void writeLong(int ptr, int value, [int offset = 0]) => write(WasmTypes.Long, ptr, value, offset);
  static void writeUnsignedLong(int ptr, int value, [int offset = 0]) => write(WasmTypes.UnsignedLong, ptr, value, offset);
  static void writeLongLong(int ptr, int value, [int offset = 0]) => write(WasmTypes.LongLong, ptr, value, offset);
  static void writeUnsignedLongLong(int ptr, int value, [int offset = 0]) => write(WasmTypes.UnsignedLongLong, ptr, value, offset);
  
  static String readString(int ptr, [int? maxLength]) {
    if (ptr == 0) return '';
    final v = view();
    final len = v.lengthInBytes;
    final limit = maxLength != null ? math.min(ptr + maxLength, len) : len;
    int end = ptr;
    while (end < limit && v.getUint8(end) != 0) end++;
    return utf8.decode(Uint8List.sublistView(v, ptr, end));
  }
  
  static void writeString(int ptr, String str) {
    final len = WasmMemory.lengthBytesUTF8(str);
    WasmMemory.stringToUTF8(str, ptr, len + 1); // +1 for null terminator
  }
  
  static int allocString(String text, [int? bufferSize]) {
    final len = lengthBytesUTF8(text) + 1; // +1 for NUL
    final bufSize = bufferSize != null && bufferSize > len ? bufferSize : len;
    final ptr = WasmMemory.malloc(bufSize);
    stringToUTF8(text, ptr, bufSize);
    return ptr;
  }
}