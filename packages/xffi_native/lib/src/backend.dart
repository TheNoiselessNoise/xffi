part of '../xffi_native.dart';

XNativePtr<X> _nativeFactory<X extends XType>(XPtr src)
  => .new((src as XNativePtr)._ptr);

XNativePtr<X> _nativeFromAddress<X extends XType>(int address)
  => .new(.fromAddress(address));

XNativePtr<XVoid> _nativeFromBytes(TypedData data) {
  final byteLength = data.buffer.lengthInBytes - data.offsetInBytes;
  final ptr = ffi.malloc<Uint8>(byteLength);
  final asBytes = data.buffer.asUint8List(data.offsetInBytes, byteLength);
  ptr.asTypedList(byteLength).setAll(0, asBytes);
  return .new(ptr.cast());
}

XNativePtr<X> _nativeNullptrFactory<X extends XType>()
  => .new(nullptr);

XNativePtr<XChar> _nativeFromString(String text, [int? bufferSize]) {
  final bytes = utf8.encode(text);
  final len = bytes.length + 1;
  final bufSize = bufferSize != null ? (bufferSize > len ? bufferSize : len) : len;
  final ptr = ffi.calloc<Uint8>(bufSize);
  ptr.asTypedList(bufSize).setRange(0, bytes.length, bytes);
  return .new(ptr);
}

XNativePtr<X> _nativeMalloc<X extends XType>(int size)
  => .new(ffi.malloc.allocate(size));

XNativePtr<X> _nativeCalloc<X extends XType>(int nmemb, int size)
  => .new(ffi.calloc.allocate(nmemb * size));

typedef XLibraryLookup = Pointer<T> Function<T extends NativeType>(String symbolName);

final class XExternalLibs {
  XExternalLibs._();

  static final Map<Type, DynamicLibrary> _libs = {};

  static DynamicLibrary register<T extends XPackageModule>(XLibrarySource source) {
    if (_libs.containsKey(T)) {
      throw StateError("A dynamic library for $T is already registered.");
    }

    return switch (source) {
      XLibrarySourcePath src => _libs[T] = .open(src.path),
      XLibrarySourceAsset src => _libs[T] = .codeAsset(src.assetId),
    };
  }

  static XLibraryLookup lookup<T extends XPackageModule>() {
    final lib = _libs[T];
    if (lib == null) {
      throw StateError("No dynamic library registered for $T.");
    }
    return lib.lookup;
  }
}

void bootMemoryBackend() {
  xffi_core.bootMemoryBackend();
  XType.nativeWordSize = sizeOf<IntPtr>();
  XPtr.factory = _nativeFactory;
  XPtr.fromAddress = _nativeFromAddress;
  XPtr.fromBytes = _nativeFromBytes;
  XPtr.fromString = _nativeFromString;
  XPtr.nullptr = _nativeNullptrFactory;
  XPtr.malloc = _nativeMalloc;
  XPtr.calloc = _nativeCalloc;

  final vsnprintf = DynamicLibrary.process().lookupFunction<
    Int32 Function(Pointer<Uint8>, IntPtr, Pointer<ffi.Utf8>, Pointer<Void>),
    int Function(Pointer<Uint8>, int, Pointer<ffi.Utf8>, Pointer<Void>)
  >('vsnprintf');

  XPrint.vsnprintf = (str, size, format, ap) => vsnprintf(str.asNative(), size, format.asNative(), ap.asNative());

  final vprintf = DynamicLibrary.process().lookupFunction<
    Void Function(Pointer<ffi.Utf8>, Pointer<Void>),
    void Function(Pointer<ffi.Utf8>, Pointer<Void>)
  >('vprintf');

  XPrint.vprintf = (format, [ap]) => vprintf(format.asNative(), ap?.asNative() ?? nullptr);
}