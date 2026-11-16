import 'dart:js_interop';
import 'dart:typed_data';
import 'package:xffi_web_vanilla/xffi_web_vanilla.dart';

@JS('dartMain')
external set _dartMain(JSFunction f);

typedef TrapCall = ({bool ok, String? error}) Function(
  JSFunction function,
  List<JSAny?> args,
);

late final DemoModule demo;
late final XWebVanillaCompatLayer layer;
late final TrapCall trap;

void start({required TrapCall trapCall}) {
  trap = trapCall;
  _dartMain = ((JSObject exports) {
    layer = XWebVanillaCompatLayer(exports);
    bootMemoryBackend(layer);
    demo = DemoModule(); // after `bootMemoryBackend`
    basicTests();
    structTests();
  }).toJS;
}

final class DemoModule with WasmBindings {
  // tests
  late final XF2<int> add;
  late final XF1<int> str_len;
  late final XF3<int> call_binop;
  late final XF3<void> call_notify;
  late final XF3<BigInt> call_i64;
  late final XF3<double> call_f32;
  late final XF3<double> call_f64;

  // structTests
  late final XF3<void> vec2_add;
  late final XF3<void> make_mixed;
  late final XF1<double> wrap_single; // single scalar struct
  late final XF3<void> call_vecfn;

  DemoModule() {
    // tests
    add = dwrap2('add');
    str_len = dwrap1('str_len');
    call_binop = dwrap3('call_binop');
    call_notify = dwrap3('call_notify');
    call_i64 = dwrap3('call_i64');
    call_f32 = dwrap3('call_f32');
    call_f64 = dwrap3('call_f64');

    // structTests
    vec2_add = swrap2('vec2_add');
    make_mixed = swrap2('make_mixed');
    wrap_single = dwrap1('wrap_single');
    call_vecfn = swrap2('call_vecfn');
  }
}

void basicTests() {
  // 1. Plain call
  final sum = demo.add(2.toJS, 3.toJS);
  layer.dummyLog('2 + 3 = $sum'); // 5

  // 2. Through the memory backend: string in, int out
  const text = 'héllo';
  final size = WasmMemory.lengthBytesUTF8(text) + 1; // + NUL
  final ptr = WasmMemory.malloc(size);
  WasmMemory.stringToUTF8(text, ptr, size);

  final len = demo.str_len(ptr.toJS);
  layer.dummyLog('byte length = $len'); // 6 (é is 2 bytes)

  WasmMemory.free(ptr);

  // 3. Read memory back (fetch a fresh view, don't cache it)
  final heap = WasmMemory.asView<Uint8List>();
  layer.dummyLog(heap.sublist(ptr, ptr + size)); // freed memory, just demonstrating access

  // 4. Return value: wasm -> Dart -> wasm
  final mul = layer.addFunction(((int a, int b) => a * b).toJS, 'iii');
  final r = demo.call_binop(mul.toJS, 6.toJS, 7.toJS);
  layer.dummyLog('binop = $r'); // 42

  // 5. Void callback with side effect
  final seen = <(int, int)>[];
  final note = layer.addFunction(((int a, int b) { seen.add((a, b)); }).toJS, 'vii');
  demo.call_notify(note.toJS, 1.toJS, 2.toJS);
  demo.call_notify(note.toJS, 3.toJS, 4.toJS);
  layer.dummyLog('notify = $seen'); // [(1, 2), (3, 4)]

  // 6. Slot reuse after removeFunction
  layer.removeFunction(mul);
  final mul2 = layer.addFunction(((int a, int b) => a + b).toJS, 'iii');
  layer.dummyLog('reused slot: ${mul2 == mul}'); // true
  final r2 = demo.call_binop(mul2.toJS, 6.toJS, 7.toJS);
  layer.dummyLog('binop (new fn) = $r2'); // 13

  // 7. Removed slot must trap
  final t4 = trap(demo.call_binop.toJS, [mul2.toJS, 1.toJS, 1.toJS]);
  layer.dummyLog(t4.ok ? 'FAIL: no trap' : 'trap ok: ${t4.error}');

  // 8. Signature mismatch must trap too
  final wrong = layer.addFunction(((int a, int b) {}).toJS, 'vii');
  final t5 = trap(demo.call_binop.toJS, [wrong.toJS, 1.toJS, 1.toJS]);
  layer.dummyLog(t5.ok ? 'FAIL: no trap' : 'mismatch trap ok: ${t5.error}');

  // i64 test
  final big = BigInt.one << 60; // beyond 2^53, a double would lose the +1
  final addI64 = layer.addFunction(
    ((JSBigInt a, JSBigInt b) => toJSBigInt(fromJSBigInt(a) + fromJSBigInt(b))).toJS,
    'jjj',
  );
  final r64 = demo.call_i64(addI64.toJS, big.toJS, BigInt.one.toJS);
  layer.dummyLog('i64 = $r64 (expect ${big + BigInt.one})'); // 1152921504606846977

  // f32 test: 0.1 is rounded to f32 on entry to wasm
  double? seenF32;
  final f32cb = layer.addFunction(
    ((JSNumber a, JSNumber b) {
      seenF32 = a.toDartDouble;
      return (a.toDartDouble * b.toDartDouble).toJS;
    }).toJS,
    'fff',
  );
  final rf = demo.call_f32(f32cb.toJS, 0.1.toJS, 2.0.toJS);
  layer.dummyLog('f32 = $rf, cb saw $seenF32'); // 0.20000000298023224, cb saw 0.10000000149011612

  // f64 test: full double precision survives
  final f64cb = layer.addFunction(
    ((JSNumber a, JSNumber b) => (a.toDartDouble + b.toDartDouble).toJS).toJS,
    'ddd',
  );
  final rd = demo.call_f64(f64cb.toJS, 0.1.toJS, 0.2.toJS);
  layer.dummyLog('f64 = $rd'); // 0.30000000000000004
}

// Float32 view index requires 4-byte alignment, Float64 8-byte; the demo's
// bump allocator returns 16-byte aligned pointers.
int _newVec2(double x, double y) {
  final p = WasmMemory.malloc(8);
  final h = WasmMemory.asView<Float32List>();
  h[p >> 2] = x;
  h[(p >> 2) + 1] = y;
  return p;
}

(double, double) _readVec2(int p) {
  final h = WasmMemory.asView<Float32List>();
  return (h[p >> 2], h[(p >> 2) + 1]);
}

void structTests() {
  // 1. sret + by-value params: out pointer first, then pointers to copies
  final a = _newVec2(1, 2), b = _newVec2(3, 4);
  final out = WasmMemory.malloc(8);
  demo.vec2_add(out.toJS, a.toJS, b.toJS);
  layer.dummyLog('vec2_add = ${_readVec2(out)}'); // (4.0, 6.0)

  // 2. Mixed layout: int at 0, double at 8 (alignment padding)
  final m = WasmMemory.malloc(16);
  demo.make_mixed(m.toJS, 7.toJS, 2.5.toJS);
  final id = WasmMemory.asView<Int32List>()[m >> 2];
  final w = WasmMemory.asView<Float64List>()[(m + 8) >> 3];
  layer.dummyLog('make_mixed = id $id, w $w'); // id 7, w 2.5

  // 3. Single-member struct: no pointers, plain f32 in and out
  final s = demo.wrap_single(2.5.toJS);
  layer.dummyLog('wrap_single = $s'); // 5.0

  // 4. Callback with struct param and struct return: 'vii' = (sret, ptr to arg)
  final cb = layer.addFunction(
    ((JSNumber outP, JSNumber inP) {
      final (x, y) = _readVec2(inP.toDartInt);
      final h = WasmMemory.asView<Float32List>();
      final o = outP.toDartInt;
      h[o >> 2] = x * 2;
      h[(o >> 2) + 1] = y * 2;
    }).toJS,
    'vii',
  );
  final out2 = WasmMemory.malloc(8);
  demo.call_vecfn(out2.toJS, cb.toJS, a.toJS);
  layer.dummyLog('call_vecfn = ${_readVec2(out2)}'); // (2.0, 4.0)

  [a, b, out, m, out2].forEach(WasmMemory.free);

  layer.removeFunction(cb);
}