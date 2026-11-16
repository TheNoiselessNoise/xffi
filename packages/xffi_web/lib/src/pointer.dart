part of '../xffi_web.dart';

final class XWasmPtr<X extends XType> extends XPtr<X> {
  final int _addr;

  XWasmPtr(this._addr);

  @override
  bool get isNull => isFreed || _addr == 0;

  @override
  void free() {
    if (_addr == 0) return;
    XDebug.checkPointer(this, 'free');
    super.free();
    WasmMemory.free(_addr);
  }

  @override
  int get address => _addr;

  @override
  T asCopy<T extends TypedDataList>(int length) {
    XDebug.checkPointer(this, 'to', T, length);
    final byteLen = length * WasmMemory._elemSize(T);
    final v = WasmMemory.view();
    // fresh buffer, offset 0 => always aligned, even if _addr isn't
    final b = Uint8List.fromList(Uint8List.sublistView(v, _addr, _addr + byteLen)).buffer;
    return switch (T) {
      const (Uint8List)   => b.asUint8List() as T,
      const (Int8List)    => b.asInt8List() as T,
      const (Uint16List)  => b.asUint16List() as T,
      const (Int16List)   => b.asInt16List() as T,
      const (Uint32List)  => b.asUint32List() as T,
      const (Int32List)   => b.asInt32List() as T,
      const (Float32List) => b.asFloat32List() as T,
      const (Float64List) => b.asFloat64List() as T,
      _ => throw UnsupportedError('XWasmPtr.asCopy<$T> not implemented'),
    };
  }

  @override
  T asView<T extends TypedDataList>(int length) {
    XDebug.checkPointer(this, 'asView', T, length);
    return WasmMemory.asView<T>(address, length);
  }

  @override
  Uint8List readBytes(int byteOffset, int length) {
    XDebug.checkPointer(this, 'readBytes', byteOffset, length);
    return .sublistView(WasmMemory.view(), _addr + byteOffset, _addr + byteOffset + length);
  }

  @override
  XWasmPtr<Y> offsetBy<Y extends XType>(int byteOffset) => .new(address + byteOffset);

  @override
  XWasmPtr<Y> readPtr<Y extends XType>([int byteOffset = 0]) {
    XDebug.checkPointer(this, 'readPtr', Y, byteOffset);
    return .new(WasmMemory.readPtr(_addr, byteOffset));
  }

  @override
  void writePtr(XPtr? value, [int byteOffset = 0]) {
    XDebug.checkPointer(this, 'writePtr', value?.address, byteOffset);
    return WasmMemory.writePtr(_addr, value?.address ?? 0, byteOffset);
  }

  @override int readSize([int byteOffset = 0]) { XDebug.checkPointer(this, 'readSize', byteOffset); final value = WasmMemory.readSize(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Size', value); return value; }
  @override bool readBool([int byteOffset = 0]) { XDebug.checkPointer(this, 'readBool', byteOffset); final value = WasmMemory.readBool(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Bool', value); return value; }
  @override int readInt8([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt8', byteOffset); final value = WasmMemory.readInt8(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Int8', value); return value; }
  @override int readUint8([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint8', byteOffset); final value = WasmMemory.readUint8(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Uint8', value); return value; }
  @override int readInt16([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt16', byteOffset); final value = WasmMemory.readInt16(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Int16', value); return value; }
  @override int readUint16([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint16', byteOffset); final value = WasmMemory.readUint16(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Uint16', value); return value; }
  @override int readInt32([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt32', byteOffset); final value = WasmMemory.readInt32(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Int32', value); return value; }
  @override int readUint32([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint32', byteOffset); final value = WasmMemory.readUint32(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Uint32', value); return value; }
  @override int readInt64([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt64', byteOffset); final value = WasmMemory.readInt64(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Int64', value); return value; }
  @override int readUint64([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint64', byteOffset); final value = WasmMemory.readUint64(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Uint64', value); return value; }
  @override double readFloat32([int byteOffset = 0]) { XDebug.checkPointer(this, 'readFloat32', byteOffset); final value = WasmMemory.readFloat32(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Float32', value); return value; }
  @override double readFloat64([int byteOffset = 0]) { XDebug.checkPointer(this, 'readFloat64', byteOffset); final value = WasmMemory.readFloat64(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Float64', value); return value; }
  @override int readChar([int byteOffset = 0]) { XDebug.checkPointer(this, 'readChar', byteOffset); final value = WasmMemory.readChar(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Char', value); return value; }
  @override int readUnsignedChar([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedChar', byteOffset); final value = WasmMemory.readUnsignedChar(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'UnsignedChar', value); return value; }
  @override int readShort([int byteOffset = 0]) { XDebug.checkPointer(this, 'readShort', byteOffset); final value = WasmMemory.readShort(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Short', value); return value; }
  @override int readUnsignedShort([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedShort', byteOffset); final value = WasmMemory.readUnsignedShort(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'UnsignedShort', value); return value; }
  @override int readInt([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt', byteOffset); final value = WasmMemory.readInt(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Int', value); return value; }
  @override int readUnsignedInt([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedInt', byteOffset); final value = WasmMemory.readUnsignedInt(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'UnsignedInt', value); return value; }
  @override double readFloat([int byteOffset = 0]) { XDebug.checkPointer(this, 'readFloat', byteOffset); final value = WasmMemory.readFloat(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Float', value); return value; }
  @override double readDouble([int byteOffset = 0]) { XDebug.checkPointer(this, 'readDouble', byteOffset); final value = WasmMemory.readDouble(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Double', value); return value; }
  @override int readLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readLong', byteOffset); final value = WasmMemory.readLong(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'Long', value); return value; }
  @override int readUnsignedLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedLong', byteOffset); final value = WasmMemory.readUnsignedLong(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'UnsignedLong', value); return value; }
  @override int readLongLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readLongLong', byteOffset); final value = WasmMemory.readLongLong(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'LongLong', value); return value; }
  @override int readUnsignedLongLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedLongLong', byteOffset); final value = WasmMemory.readUnsignedLongLong(_addr, byteOffset); XTrace.checkRead(_addr + byteOffset, 'UnsignedLongLong', value); return value; }

  @override void writeSize(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeSize', value, byteOffset); WasmMemory.writeSize(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Size', value); }
  @override void writeBool(bool value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeBool', value, byteOffset); WasmMemory.writeBool(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Bool', value); }
  @override void writeInt8(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt8', value, byteOffset); WasmMemory.writeInt8(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Int8', value); }
  @override void writeUint8(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint8', value, byteOffset); WasmMemory.writeUint8(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Uint8', value); }
  @override void writeInt16(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt16', value, byteOffset); WasmMemory.writeInt16(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Int16', value); }
  @override void writeUint16(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint16', value, byteOffset); WasmMemory.writeUint16(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Uint16', value); }
  @override void writeInt32(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt32', value, byteOffset); WasmMemory.writeInt32(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Int32', value); }
  @override void writeUint32(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint32', value, byteOffset); WasmMemory.writeUint32(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Uint32', value); }
  @override void writeInt64(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt64', value, byteOffset); WasmMemory.writeInt64(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Int64', value); }
  @override void writeUint64(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint64', value, byteOffset); WasmMemory.writeUint64(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Uint64', value); }
  @override void writeFloat32(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeFloat32', value, byteOffset); WasmMemory.writeFloat32(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Float32', value); }
  @override void writeFloat64(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeFloat64', value, byteOffset); WasmMemory.writeFloat64(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Float64', value); }
  @override void writeChar(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeChar', value, byteOffset); WasmMemory.writeChar(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Char', value); }
  @override void writeUnsignedChar(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedChar', value, byteOffset); WasmMemory.writeUnsignedChar(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'UnsignedChar', value); }
  @override void writeShort(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeShort', value, byteOffset); WasmMemory.writeShort(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Short', value); }
  @override void writeUnsignedShort(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedShort', value, byteOffset); WasmMemory.writeUnsignedShort(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'UnsignedShort', value); }
  @override void writeInt(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt', value, byteOffset); WasmMemory.writeInt(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Int', value); }
  @override void writeUnsignedInt(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedInt', value, byteOffset); WasmMemory.writeUnsignedInt(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'UnsignedInt', value); }
  @override void writeFloat(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeFloat', value, byteOffset); WasmMemory.writeFloat(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Float', value); }
  @override void writeDouble(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeDouble', value, byteOffset); WasmMemory.writeDouble(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Double', value); }
  @override void writeLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeLong', value, byteOffset); WasmMemory.writeLong(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'Long', value); }
  @override void writeUnsignedLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedLong', value, byteOffset); WasmMemory.writeUnsignedLong(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'UnsignedLong', value); }
  @override void writeLongLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeLongLong', value, byteOffset); WasmMemory.writeLongLong(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'LongLong', value); }
  @override void writeUnsignedLongLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedLongLong', value, byteOffset); WasmMemory.writeUnsignedLongLong(_addr, value, byteOffset); XTrace.checkWrite(_addr + byteOffset, 'UnsignedLongLong', value); }
}

extension XPtrAsWasmPtr on XPtr {
  JSNumber get toJS => (this as XWasmPtr).address.toJS;
}

extension XStructPtrAsWasmPtr on XStructPtr {
  JSNumber get toJS => (ptr as XWasmPtr).toJS;
}

extension JSAnyAsXPtr on JSAny? {
  XWasmPtr<X> asXPtr<X extends XType>() {
    final addr = toNullableInt();
    if (addr == null) throw StateError('XWasmPtr needs `integer` value as an address.');
    return .new(addr);
  }
}