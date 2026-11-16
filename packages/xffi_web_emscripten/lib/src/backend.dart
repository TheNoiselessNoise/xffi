part of '../xffi_web_emscripten.dart';

@JS('Module')
external EmscriptenModule get _emscriptenModule;

@JS('HEAPU8')
external _HEAPU8 get _heapu8;

@JS()
extension type _HEAPU8._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

extension type EmscriptenModule._(JSObject _) implements JSObject {
  external JSFunction cwrap(JSString name, JSAny? returnType, JSArray argTypes);
  external int _malloc(int size);
  external int _calloc(int nmemb, int size);
  external void _free(int ptr);
  external int _memset(int ptr, int value, int size);
  external void stringToUTF8(JSString str, int ptr, int maxLen);
  external int lengthBytesUTF8(JSString str);

  @JS('print')
  external void _print(JSAny? value);
  void print(List<Object?> values) => _print(values.map((o) => o.toString()).join(' ').toJS);

  @JS('addFunction')
  external int addFunction(JSFunction func, JSString signature);

  @JS('removeFunction')
  external int removeFunction(JSNumber index);

  int getAddress(String name) {
    final v = getProperty(name.toJS);
    if (v.isUndefinedOrNull) return 0;
    return (v as JSAny).toInt();
  }
}

final class _XWebEmscriptenCompatLayer extends WasmCompatibilityLayer {
  final EmscriptenModule _m;

  _XWebEmscriptenCompatLayer._(this._m);

  late final String _n = 'number';
  late final List<String> _nAll = [_n, _n, _n, _n, _n, _n, _n, _n, _n];
  
  @override
  ByteBuffer buf()
    => _heapu8.buffer.toDart;

  @override
  int malloc(int size)
    => _m._malloc(size);

  @override
  int calloc(int nmemb, int size)
    => _m._calloc(nmemb, size);

  @override
  void free(int ptr)
    => _m._free(ptr);

  @override
  int memset(int ptr, int value, int size)
    => _m._memset(ptr, value, size);

  @override
  void stringToUTF8(String str, int ptr, int maxLen)
    => _m.stringToUTF8(str.toJS, ptr, maxLen);

  @override
  int lengthBytesUTF8(String str)
    => _m.lengthBytesUTF8(str.toJS);

  @override
  int addFunction(JSFunction f, String sig)
    => _m.addFunction(f, sig.toJS);

  @override
  void removeFunction(int i)
    => _m.removeFunction(i.toJS);

  @override
  int getAddress(String name)
    => _m.getAddress(name);

  @override
  JSFunction<Function> wrap(String name, int arity)
    => dwrap(name, _nAll.sublist(0, arity), _n);

  
  @override
  JSFunction<Function> swrap(String name, int arity)
    => dwrap(name, _nAll.sublist(0, arity + 1), null);
  
  @override
  JSFunction dwrap(String name, [List<String> argTypes = const [], String? returnType])
    => _m.cwrap(name.toJS, returnType?.toJS, argTypes.map((e) => e.toJS).toList().toJS);
}

void bootMemoryBackend() {
  web.bootMemoryBackend(_XWebEmscriptenCompatLayer._(_emscriptenModule));
  _registerEmscriptenHelpers();
}