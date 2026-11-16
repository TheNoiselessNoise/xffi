part of '../xffi_web_vanilla.dart';

@JS('WebAssembly.Memory')
extension type _JSMemory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

@JS('WebAssembly.Module')
extension type _JSModule._(JSObject _) implements JSObject {
  external factory _JSModule(JSUint8Array bytes);
}

@JS('WebAssembly.Instance')
extension type _JSInstance._(JSObject _) implements JSObject {
  external factory _JSInstance(_JSModule module, JSObject imports);
  external JSObject get exports;
}

@JS('WebAssembly.Table')
extension type _JSTable._(JSObject _) implements JSObject {
  external int get length;
  external int grow(int delta);
  external void set(int index, JSAny? value);
}

final class XWebVanillaCompatLayer extends WasmCompatibilityLayer {
  final String memoryExport;

  XWebVanillaCompatLayer(this.exports, {this.memoryExport = 'memory'}) {
    final t = exports.getProperty<JSAny?>('__indirect_function_table'.toJS);
    if (t == null) {
      throw StateError(
        'module must export __indirect_function_table '
        '(link with --export-table --growable-table)'
      );
    }
    _table = t as _JSTable;
  }

  JSFunction _fn(String name) {
    final f = exports.getProperty<JSAny?>(name.toJS);
    if (f == null) throw StateError('wasm module does not export "$name"');
    return f as JSFunction;
  }

  // Emscripten signature letters: first = return type (v = void), rest = params.
  final _valType = {'i': 0x7f, 'j': 0x7e, 'f': 0x7d, 'd': 0x7c};

  List<int> _leb(int n) {
    final out = <int>[];
    do {
      var b = n & 0x7f;
      n >>= 7;
      if (n != 0) b |= 0x80;
      out.add(b);
    } while (n != 0);
    return out;
  }

  List<int> _section(int id, List<int> body) => [id, ..._leb(body.length), ...body];

  /// Tiny module: imports `e.f` with the given signature and re-exports it as `f`.
  /// A re-exported imported JS function becomes a real wasm function, which is
  /// what `table.set` requires.
  Uint8List _trampolineBytes(String sig) {
    final ret = sig[0];
    final params = sig.substring(1).split('');
    final type = [
      0x60,
      ..._leb(params.length),
      for (final c in params) _valType[c]!,
      if (ret == 'v') 0 else ...[1, _valType[ret]!],
    ];
    return .fromList([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
      ..._section(1, [1, ...type]),                      // types
      ..._section(2, [1, 1, 0x65, 1, 0x66, 0x00, 0x00]), // import e.f (func, type 0)
      ..._section(7, [1, 1, 0x66, 0x00, 0x00]),          // export f (func 0)
    ]);
  }

  final JSObject exports;
  late final _JSTable _table;
  final _freeSlots = <int>[];
  final _trampolines = <String, _JSModule>{};

  late final memory = exports.getProperty<_JSMemory>(memoryExport.toJS);
  late final JSFunction _malloc = _fn('malloc');
  late final JSFunction _free = _fn('free');

  @override
  ByteBuffer buf()
    => memory.buffer.toDart;

  @override
  int malloc(int size)
    => _malloc.run([size.toJS]).toInt();
  
  @override
  int calloc(int nmemb, int size) {
    final n = nmemb * size;
    final p = malloc(n);
    if (p != 0) memset(p, 0, n);
    return p;
  }
  
  @override
  void free(int ptr)
    => _free.run([ptr.toJS]);
  
  @override
  int memset(int ptr, int value, int num) {
    Uint8List.view(buf(), ptr, num).fillRange(0, num, value);
    return ptr;
  }

  @override
  void stringToUTF8(String str, int ptr, int maxLen) {
    if (maxLen <= 0) return;
    final bytes = utf8.encode(str);
    var n = bytes.length < maxLen - 1 ? bytes.length : maxLen - 1;
    // don't cut a multibyte sequence in half
    while (n > 0 && n < bytes.length && (bytes[n] & 0xC0) == 0x80) n--;
    final heap = Uint8List.view(buf());
    heap.setRange(ptr, ptr + n, bytes);
    heap[ptr + n] = 0;
  }

  @override
  int lengthBytesUTF8(String str)
    => utf8.encode(str).length;

  /// [func] must be a JS function (`dartFn.toJS`). i64 params/returns are BigInt.
  @override
  int addFunction(JSFunction func, String signature) {
    final module = _trampolines.putIfAbsent(signature, () => _JSModule(_trampolineBytes(signature).toJS));
    final env = JSObject()..setProperty('f'.toJS, func);
    final imports = JSObject()..setProperty('e'.toJS, env);
    final fn = _JSInstance(module, imports).exports.getProperty<JSFunction>('f'.toJS);
    final idx = _freeSlots.isNotEmpty ? _freeSlots.removeLast() : _table.grow(1);
    _table.set(idx, fn);
    return idx;
  }

  @override
  void removeFunction(int index) {
    _table.set(index, null);
    _freeSlots.add(index);
  }

  /// Data symbols exported by wasm-ld (`--export=foo`) are `WebAssembly.Global`s
  /// holding the address. Function exports have no address, use the table for those.
  @override
  int getAddress(String name) {
    final v = exports.getProperty<JSAny?>(name.toJS); // no leading underscore in vanilla
    if (v == null) return 0;
    if (v.isA<JSNumber>()) return (v as JSNumber).toDartInt;
    return (v as JSObject).getProperty<JSNumber>('value'.toJS).toDartInt;
  }

  @override
  JSFunction<Function> wrap(String name, int arity)
    => dwrap(name);
  
  @override
  JSFunction<Function> swrap(String name, int arity)
    => dwrap(name);

  /// No cwrap: returns the raw export.
  @override
  JSFunction dwrap(String name, [List<String> argTypes = const [], String? returnType]) {
    final f = exports.getProperty<JSAny?>(name.toJS);
    if (f == null) throw StateError('wasm module does not export "$name"');
    return f as JSFunction;
  }
}

void bootMemoryBackend(XWebVanillaCompatLayer layer) {
  web.bootMemoryBackend(layer);
}

Future<XWebVanillaCompatLayer> loadVanilla(String url, {JSObject? imports}) async {
  final wasm = globalContext.getProperty<JSObject>('WebAssembly'.toJS);
  final result = await wasm.callMethod<JSPromise<JSObject>>(
    'instantiateStreaming'.toJS,
    web.window.fetch(url.toJS),
    imports ?? JSObject(),
  ).toDart;
  final exports = result
    .getProperty<JSObject>('instance'.toJS)
    .getProperty<JSObject>('exports'.toJS);
  return .new(exports);
}