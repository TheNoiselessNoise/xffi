part of '../xffi_native.dart';

final class XNativePtr<X extends XType> extends XPtr<X> {
  final Pointer _ptr; // untyped pointer

  XNativePtr(this._ptr);

  /* --- NATIVE SPECIFIC --- */

  Pointer<Y> _asPointer<Y extends NativeType>() => _ptr.cast();

  /* --- --------------- --- */

  @override
  bool get isNull => isFreed || _ptr == nullptr;

  @override
  void free() {
    if (_ptr == nullptr) return;
    XDebug.checkPointer(this, 'free');
    super.free();
    ffi.malloc.free(_ptr);
  }

  @override
  int get address => _ptr.address;

  @override
  T asCopy<T extends TypedDataList>(int length) {
    XDebug.checkPointer(this, 'to', T, length);
    return switch (T) {
      const (Uint8List) => Uint8List.fromList(_ptr.cast<Uint8>().asTypedList(length)) as T,
      const (Int8List) => Int8List.fromList(_ptr.cast<Int8>().asTypedList(length)) as T,
      const (Uint16List) => Uint16List.fromList(_ptr.cast<Uint16>().asTypedList(length)) as T,
      const (Int16List) => Int16List.fromList(_ptr.cast<Int16>().asTypedList(length)) as T,
      const (Uint32List) => Uint32List.fromList(_ptr.cast<Uint32>().asTypedList(length)) as T,
      const (Int32List) => Int32List.fromList(_ptr.cast<Int32>().asTypedList(length)) as T,
      const (Uint64List) => Uint64List.fromList(_ptr.cast<Uint64>().asTypedList(length)) as T,
      const (Int64List) => Int64List.fromList(_ptr.cast<Int64>().asTypedList(length)) as T,
      const (Float32List) => Float32List.fromList(_ptr.cast<Float>().asTypedList(length)) as T,
      const (Float64List) => Float64List.fromList(_ptr.cast<Double>().asTypedList(length)) as T,
      _ => throw UnsupportedError('XNativePtr.to<$T> not implemented'),
    };
  }

  @override
  T asView<T extends TypedDataList>(int length) {
    XDebug.checkPointer(this, 'asView', T, length);
    return switch (T) {
      const (Uint8List) => _ptr.cast<Uint8>().asTypedList(length) as T,
      const (Int8List) => _ptr.cast<Int8>().asTypedList(length) as T,
      const (Uint16List) => _ptr.cast<Uint16>().asTypedList(length) as T,
      const (Int16List) => _ptr.cast<Int16>().asTypedList(length) as T,
      const (Uint32List) => _ptr.cast<Uint32>().asTypedList(length) as T,
      const (Int32List) => _ptr.cast<Int32>().asTypedList(length) as T,
      const (Uint64List) => _ptr.cast<Uint64>().asTypedList(length) as T,
      const (Int64List) => _ptr.cast<Int64>().asTypedList(length) as T,
      const (Float32List) => _ptr.cast<Float>().asTypedList(length) as T,
      const (Float64List) => _ptr.cast<Double>().asTypedList(length) as T,
      _ => throw UnsupportedError('XNativePtr.asView<$T> not implemented'),
    };
  }

  @override
  Uint8List readBytes(int byteOffset, int length) =>
    (_ptr.cast<Uint8>() + byteOffset).asTypedList(length);

  @override
  XNativePtr<Y> offsetBy<Y extends XType>(int byteOffset) => .new(_at(byteOffset));

  Pointer<T> _at<T extends NativeType>(int byteOffset)
    => (_ptr.cast<Uint8>() + byteOffset).cast<T>();

  @override
  XNativePtr<Y> readPtr<Y extends XType>([int byteOffset = 0]) {
    XDebug.checkPointer(this, 'readPtr', Y, byteOffset);
    return .new(.fromAddress(Pointer<IntPtr>.fromAddress(address + byteOffset).value));
  }

  @override
  void writePtr(XPtr? value, [int byteOffset = 0]) {
    XDebug.checkPointer(this, 'writePtr', value?.address, byteOffset);
    Pointer<IntPtr>.fromAddress(address + byteOffset).value = value?.address ?? nullptr.address;
  }

  @override int readSize([int byteOffset = 0]) { XDebug.checkPointer(this, 'readSize', byteOffset); final ptr = _at<Size>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Size', value); return value; }
  @override bool readBool([int byteOffset = 0]) { XDebug.checkPointer(this, 'readBool', byteOffset); final ptr = _at<Bool>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Bool', value); return value; }
  @override int readInt8([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt8', byteOffset); final ptr = _at<Int8>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Int8', value); return value; }
  @override int readUint8([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint8', byteOffset); final ptr = _at<Uint8>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Uint8', value); return value; }
  @override int readInt16([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt16', byteOffset); final ptr = _at<Int16>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Int16', value); return value; }
  @override int readUint16([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint16', byteOffset); final ptr = _at<Uint16>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Uint16', value); return value; }
  @override int readInt32([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt32', byteOffset); final ptr = _at<Int32>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Int32', value); return value; }
  @override int readUint32([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint32', byteOffset); final ptr = _at<Uint32>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Uint32', value); return value; }
  @override int readInt64([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt64', byteOffset); final ptr = _at<Int64>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Int64', value); return value; }
  @override int readUint64([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUint64', byteOffset); final ptr = _at<Uint64>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Uint64', value); return value; }
  @override double readFloat32([int byteOffset = 0]) { XDebug.checkPointer(this, 'readFloat32', byteOffset); final ptr = _at<Float>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Float', value); return value; }
  @override double readFloat64([int byteOffset = 0]) { XDebug.checkPointer(this, 'readFloat64', byteOffset); final ptr = _at<Double>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Double', value); return value; }
  @override int readChar([int byteOffset = 0]) { XDebug.checkPointer(this, 'readChar', byteOffset); final ptr = _at<Char>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Char', value); return value; }
  @override int readUnsignedChar([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedChar', byteOffset); final ptr = _at<UnsignedChar>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'UnsignedChar', value); return value; }
  @override int readShort([int byteOffset = 0]) { XDebug.checkPointer(this, 'readShort', byteOffset); final ptr = _at<Short>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Short', value); return value; }
  @override int readUnsignedShort([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedShort', byteOffset); final ptr = _at<UnsignedShort>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'UnsignedShort', value); return value; }
  @override int readInt([int byteOffset = 0]) { XDebug.checkPointer(this, 'readInt', byteOffset); final ptr = _at<Int>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Int', value); return value; }
  @override int readUnsignedInt([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedInt', byteOffset); final ptr = _at<UnsignedInt>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'UnsignedInt', value); return value; }
  @override double readFloat([int byteOffset = 0]) { XDebug.checkPointer(this, 'readFloat', byteOffset); final ptr = _at<Float>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Float', value); return value; }
  @override double readDouble([int byteOffset = 0]) { XDebug.checkPointer(this, 'readDouble', byteOffset); final ptr = _at<Double>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Double', value); return value; }
  @override int readLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readLong', byteOffset); final ptr = _at<Long>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'Long', value); return value; }
  @override int readUnsignedLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedLong', byteOffset); final ptr = _at<UnsignedLong>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'UnsignedLong', value); return value; }
  @override int readLongLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readLongLong', byteOffset); final ptr = _at<LongLong>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'LongLong', value); return value; }
  @override int readUnsignedLongLong([int byteOffset = 0]) { XDebug.checkPointer(this, 'readUnsignedLongLong', byteOffset); final ptr = _at<UnsignedLongLong>(byteOffset); final value = ptr.value; XTrace.checkRead(ptr.address, 'UnsignedLongLong', value); return value; }

  @override void writeSize(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeSize', value, byteOffset); final ptr = _at<Size>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Size', value); }
  @override void writeBool(bool value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeBool', value, byteOffset); final ptr = _at<Bool>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Bool', value); }
  @override void writeInt8(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt8', value, byteOffset); final ptr = _at<Int8>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Int8', value); }
  @override void writeUint8(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint8', value, byteOffset); final ptr = _at<Uint8>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Uint8', value); }
  @override void writeInt16(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt16', value, byteOffset); final ptr = _at<Int16>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Int16', value); }
  @override void writeUint16(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint16', value, byteOffset); final ptr = _at<Uint16>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Uint16', value); }
  @override void writeInt32(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt32', value, byteOffset); final ptr = _at<Int32>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Int32', value); }
  @override void writeUint32(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint32', value, byteOffset); final ptr = _at<Uint32>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Uint32', value); }
  @override void writeInt64(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt64', value, byteOffset); final ptr = _at<Int64>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Int64', value); }
  @override void writeUint64(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUint64', value, byteOffset); final ptr = _at<Uint64>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Uint64', value); }
  @override void writeFloat32(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeFloat32', value, byteOffset); final ptr = _at<Float>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Float', value); }
  @override void writeFloat64(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeFloat64', value, byteOffset); final ptr = _at<Double>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Double', value); }
  @override void writeChar(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeChar', value, byteOffset); final ptr = _at<Char>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Char', value); }
  @override void writeUnsignedChar(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedChar', value, byteOffset); final ptr = _at<UnsignedChar>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'UnsignedChar', value); }
  @override void writeShort(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeShort', value, byteOffset); final ptr = _at<Short>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Short', value); }
  @override void writeUnsignedShort(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedShort', value, byteOffset); final ptr = _at<UnsignedShort>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'UnsignedShort', value); }
  @override void writeInt(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeInt', value, byteOffset); final ptr = _at<Int>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Int', value); }
  @override void writeUnsignedInt(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedInt', value, byteOffset); final ptr = _at<UnsignedInt>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'UnsignedInt', value); }
  @override void writeFloat(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeFloat', value, byteOffset); final ptr = _at<Float>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Float', value); }
  @override void writeDouble(double value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeDouble', value, byteOffset); final ptr = _at<Double>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Double', value); }
  @override void writeLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeLong', value, byteOffset); final ptr = _at<Long>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'Long', value); }
  @override void writeUnsignedLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedLong', value, byteOffset); final ptr = _at<UnsignedLong>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'UnsignedLong', value); }
  @override void writeLongLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeLongLong', value, byteOffset); final ptr = _at<LongLong>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'LongLong', value); }
  @override void writeUnsignedLongLong(int value, [int byteOffset = 0]) { XDebug.checkPointer(this, 'writeUnsignedLongLong', value, byteOffset); final ptr = _at<UnsignedLongLong>(byteOffset); ptr.value = value; XTrace.checkWrite(ptr.address, 'UnsignedLongLong', value); }
}

extension XPtrAsNativePointer on XPtr {
  Pointer<X> asNative<X extends NativeType>() => (this as XNativePtr)._asPointer();
}

extension XStructPtrAsNativePtr on XStructPtr {
  Pointer<X> asNative<X extends NativeType>() => (ptr as XNativePtr).asNative();
}

extension NativePtrAsXPtr on Pointer {
  XNativePtr<X> asXPtr<X extends XType>() => .new(this);
}