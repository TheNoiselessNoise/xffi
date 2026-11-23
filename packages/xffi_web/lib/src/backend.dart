part of '../xffi_web.dart';

XWasmPtr<X> _wasmFactory<X extends XType>(XPtr src)
  => .new((src as XWasmPtr).address);

XWasmPtr<X> _wasmFromAddress<X extends XType>(int address)
  => .new(address);

XWasmPtr<XVoid> _wasmFromBytes(TypedData data) {
  final byteLength = data.lengthInBytes;
  final asBytes = data.buffer.asUint8List(data.offsetInBytes, byteLength);
  final addr = WasmMemory.malloc(byteLength);
  final v = WasmMemory.view();
  v.buffer.asUint8List(v.offsetInBytes + addr, byteLength).setAll(0, asBytes);
  return .new(addr);
}

XWasmPtr<XChar> _wasmFromString(String text, [int? bufferSize])
  => .new(WasmMemory.allocString(text, bufferSize));

XWasmPtr<X> _wasmNullptrFactory<X extends XType>()
  => .new(0);

XWasmPtr<X> _wasmMalloc<X extends XType>(int size)
  => .new(WasmMemory.malloc(size));

XWasmPtr<X> _wasmCalloc<X extends XType>(int nmemb, int size)
  => .new(WasmMemory.calloc(nmemb, size));

class XWebVanillaCoreLib with WasmBindings {
  late final XF4<int> vsnprintf;
  late final XF2<void> vprintf;

  XWebVanillaCoreLib() {
    vsnprintf = dwrap4('vsnprintf');
    vprintf = dwrap2('vprintf');
  }
}

/// Base class for WASM-backed modules.
///
/// Arity and (sort of) type-checked `wrap` bindings.
abstract class XPackageModuleWasm<X extends XPackage> extends XPackageModule<X> with WasmBindings {
  XPackageModuleWasm(super.rl);
}

void bootMemoryBackend(WasmCompatibilityLayer layer) {
  xffi_core.bootMemoryBackend();
  XType.nativeWordSize = WasmSize.Int32; // 4
  XPtr.factory = _wasmFactory;
  XPtr.fromAddress = _wasmFromAddress;
  XPtr.fromBytes = _wasmFromBytes;
  XPtr.fromString = _wasmFromString;
  XPtr.nullptr = _wasmNullptrFactory;
  XPtr.malloc = _wasmMalloc;
  XPtr.calloc = _wasmCalloc;
  WasmMemory.view = () => layer.buf().asByteData();
  WasmMemory.malloc = layer.malloc;
  WasmMemory.calloc = layer.calloc;
  WasmMemory.free = layer.free;
  WasmMemory.memset = layer.memset;
  WasmMemory.stringToUTF8 = layer.stringToUTF8;
  WasmMemory.lengthBytesUTF8 = layer.lengthBytesUTF8;
  WasmMemory.addFunction = layer.addFunction;
  WasmMemory.removeFunction = layer.removeFunction;
  WasmMemory.wrap = layer.wrap;
  WasmMemory.swrap = layer.swrap;
  WasmMemory.symbol = layer.symbol;
  final coreLib = XWebVanillaCoreLib();
  XPrint.vsnprintf = (str, size, format, ap) => coreLib.vsnprintf(str.toJS, size.toJS, format.toJS, ap.toJS);
  XPrint.vprintf = (format, [ap]) => coreLib.vprintf(format.toJS, (ap ?? XPtr.nullptr()).toJS);
}