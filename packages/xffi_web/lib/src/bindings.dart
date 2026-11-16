part of '../xffi_web.dart';

typedef XN = JSAny;
typedef XF0<R> = R Function();
typedef XF1<R> = R Function(XN);
typedef XF2<R> = R Function(XN, XN);
typedef XF3<R> = R Function(XN, XN, XN);
typedef XF4<R> = R Function(XN, XN, XN, XN);
typedef XF5<R> = R Function(XN, XN, XN, XN, XN);
typedef XF6<R> = R Function(XN, XN, XN, XN, XN, XN);
typedef XF7<R> = R Function(XN, XN, XN, XN, XN, XN, XN);
typedef XF8<R> = R Function(XN, XN, XN, XN, XN, XN, XN, XN);
typedef XF9<R> = R Function(XN, XN, XN, XN, XN, XN, XN, XN, XN);

/// Typed, fixed-arity helpers for declaring bindings to exported WASM functions.
mixin WasmBindings {
  /// Resolves a global symbol exported by the WASM module and wraps its
  /// address as a [XWasmPtr].
  ///
  /// `name` is the C symbol name.
  /// `X` is a marker only.
  ///
  /// Use this for global variables/constants exported by the module.
  XWasmPtr<X> symbol<X extends XType>(String name) => WasmMemory.symbol(name);

  /// Resolves the JS->Dart conversion for a binding's return type, once at
  /// bind time. Unrecognized `X` (including `void` and `JSAny?` subtypes)
  /// falls through to a plain cast.
  X Function(JSAny?) _conv<X>() {
    if (X == int) return (v) => v.toInt() as X;
    if (X == double) return (v) => v.toDouble() as X;
    if (X == bool) return (v) => v.toBool() as X;
    if (X == String) return (v) => v.toDartString() as X;
    if (X == BigInt) return (v) => fromJSBigInt(v as JSBigInt) as X;
    return (v) => v as dynamic;
  }

  /// Binds a `wrap`ed C function taking `0` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF0<X> dwrap0<X>(String name) {
    final f = WasmMemory.wrap(name, 0);
    final c = _conv<X>();
    return () => c(f.run());
  }

  /// Binds a `wrap`ed C function taking `0` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The single parameter is the caller-allocated pointer the struct is
  /// written into. Always returns `void`, read the result back out of
  /// the pointer you passed in.
  XF1<void> swrap0(String name) {
    final f = WasmMemory.swrap(name, 0);
    return (a1) => f.run([a1]);
  }

  /// Binds a `wrap`ed C function taking `0` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF0<XWasmPtr<X>> pwrap0<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 0);
    return () => f.run().asXPtr();
  }

  /// Binds a `wrap`ed C function taking `0` arguments and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF0<XStructPtr<X>> qwrap0<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 0);
    final struct = XStructDefinitions.of<X>();
    return () => struct.ptr(XWasmPtr(f.run().toInt()));
  }

  /// Binds a `wrap`ed C function taking `1` argument and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF1<X> dwrap1<X>(String name) {
    final f = WasmMemory.wrap(name, 1);
    final c = _conv<X>();
    return (a1) => c(f.run([a1]));
  }

  /// Binds a `wrap`ed C function taking `1` argument that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real argument. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF2<void> swrap1(String name) {
    final f = WasmMemory.swrap(name, 1);
    return (a1, a2) => f.run([a1, a2]);
  }

  /// Binds a `wrap`ed C function taking `1` argument and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF1<XWasmPtr<X>> pwrap1<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 1);
    return (a1) => f.run([a1]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `1` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF1<XStructPtr<X>> qwrap1<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 1);
    final struct = XStructDefinitions.of<X>();
    return (a1) => struct.ptr(XWasmPtr(f.run([a1]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `2` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF2<X> dwrap2<X>(String name) {
    final f = WasmMemory.wrap(name, 2);
    final c = _conv<X>();
    return (a1, a2) => c(f.run([a1, a2]));
  }

  /// Binds a `wrap`ed C function taking `2` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF3<void> swrap2(String name) {
    final f = WasmMemory.swrap(name, 2);
    return (a1, a2, a3) => f.run([a1, a2, a3]);
  }

  /// Binds a `wrap`ed C function taking `2` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF2<XWasmPtr<X>> pwrap2<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 2);
    return (a1, a2) => f.run([a1, a2]).asXPtr();
  }
  
  /// Binds a `wrap`ed C function taking `2` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF2<XStructPtr<X>> qwrap2<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 2);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2) => struct.ptr(XWasmPtr(f.run([a1, a2]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `3` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF3<X> dwrap3<X>(String name) {
    final f = WasmMemory.wrap(name, 3);
    final c = _conv<X>();
    return (a1, a2, a3) => c(f.run([a1, a2, a3]));
  }

  /// Binds a `wrap`ed C function taking `3` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF4<void> swrap3(String name) {
    final f = WasmMemory.swrap(name, 3);
    return (a1, a2, a3, a4) => f.run([a1, a2, a3, a4]);
  }
  
  /// Binds a `wrap`ed C function taking `3` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF3<XWasmPtr<X>> pwrap3<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 3);
    return (a1, a2, a3) => f.run([a1, a2, a3]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `3` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF3<XStructPtr<X>> qwrap3<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 3);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3) => struct.ptr(XWasmPtr(f.run([a1, a2, a3]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `4` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF4<X> dwrap4<X>(String name) {
    final f = WasmMemory.wrap(name, 4);
    final c = _conv<X>();
    return (a1, a2, a3, a4) => c(f.run([a1, a2, a3, a4]));
  }

  /// Binds a `wrap`ed C function taking `4` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF5<void> swrap4(String name) {
    final f = WasmMemory.swrap(name, 4);
    return (a1, a2, a3, a4, a5) => f.run([a1, a2, a3, a4, a5]);
  }

  /// Binds a `wrap`ed C function taking `4` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF4<XWasmPtr<X>> pwrap4<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 4);
    return (a1, a2, a3, a4) => f.run([a1, a2, a3, a4]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `4` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF4<XStructPtr<X>> qwrap4<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 4);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3, a4) => struct.ptr(XWasmPtr(f.run([a1, a2, a3, a4]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `5` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF5<X> dwrap5<X>(String name) {
    final f = WasmMemory.wrap(name, 5);
    final c = _conv<X>();
    return (a1, a2, a3, a4, a5) => c(f.run([a1, a2, a3, a4, a5]));
  }

  /// Binds a `wrap`ed C function taking `5` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF6<void> swrap5(String name) {
    final f = WasmMemory.swrap(name, 5);
    return (a1, a2, a3, a4, a5, a6) => f.run([a1, a2, a3, a4, a5, a6]);
  }

  /// Binds a `wrap`ed C function taking `5` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF5<XWasmPtr<X>> pwrap5<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 5);
    return (a1, a2, a3, a4, a5) => f.run([a1, a2, a3, a4, a5]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `5` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF5<XStructPtr<X>> qwrap5<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 5);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3, a4, a5) => struct.ptr(XWasmPtr(f.run([a1, a2, a3, a4, a5]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `6` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF6<X> dwrap6<X>(String name) {
    final f = WasmMemory.wrap(name, 6);
    final c = _conv<X>();
    return (a1, a2, a3, a4, a5, a6) => c(f.run([a1, a2, a3, a4, a5, a6]));
  }

  /// Binds a `wrap`ed C function taking `6` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF7<void> swrap6(String name) {
    final f = WasmMemory.swrap(name, 6);
    return (a1, a2, a3, a4, a5, a6, a7) => f.run([a1, a2, a3, a4, a5, a6, a7]);
  }

  /// Binds a `wrap`ed C function taking `6` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF6<XWasmPtr<X>> pwrap6<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 6);
    return (a1, a2, a3, a4, a5, a6) => f.run([a1, a2, a3, a4, a5, a6]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `6` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF6<XStructPtr<X>> qwrap6<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 6);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3, a4, a5, a6) => struct.ptr(XWasmPtr(f.run([a1, a2, a3, a4, a5, a6]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `7` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF7<X> dwrap7<X>(String name) {
    final f = WasmMemory.wrap(name, 7);
    final c = _conv<X>();
    return (a1, a2, a3, a4, a5, a6, a7) => c(f.run([a1, a2, a3, a4, a5, a6, a7]));
  }

  /// Binds a `wrap`ed C function taking `7` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF8<void> swrap7(String name) {
    final f = WasmMemory.swrap(name, 7);
    return (a1, a2, a3, a4, a5, a6, a7, a8) => f.run([a1, a2, a3, a4, a5, a6, a7, a8]);
  }

  /// Binds a `wrap`ed C function taking `7` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF7<XWasmPtr<X>> pwrap7<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 7);
    return (a1, a2, a3, a4, a5, a6, a7) => f.run([a1, a2, a3, a4, a5, a6, a7]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `7` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF7<XStructPtr<X>> qwrap7<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 7);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3, a4, a5, a6, a7) => struct.ptr(XWasmPtr(f.run([a1, a2, a3, a4, a5, a6, a7]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `8` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF8<X> dwrap8<X>(String name) {
    final f = WasmMemory.wrap(name, 8);
    final c = _conv<X>();
    return (a1, a2, a3, a4, a5, a6, a7, a8) => c(f.run([a1, a2, a3, a4, a5, a6, a7, a8]));
  }

  /// Binds a `wrap`ed C function taking `8` arguments that returns a struct
  /// via the WASM structure-return (`sret`) convention.
  ///
  /// The first parameter is the caller-allocated pointer the struct is
  /// written into, followed by the function's real arguments. Always
  /// returns `void`, read the result back out of the pointer you passed in.
  XF9<void> swrap8(String name) {
    final f = WasmMemory.swrap(name, 8);
    return (a1, a2, a3, a4, a5, a6, a7, a8, a9) => f.run([a1, a2, a3, a4, a5, a6, a7, a8, a9]);
  }

  /// Binds a `wrap`ed C function taking `8` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF8<XWasmPtr<X>> pwrap8<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 8);
    return (a1, a2, a3, a4, a5, a6, a7, a8) => f.run([a1, a2, a3, a4, a5, a6, a7, a8]).asXPtr();
  }
  
  /// Binds a `wrap`ed C function taking `8` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF8<XStructPtr<X>> qwrap8<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 8);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3, a4, a5, a6, a7, a8) => struct.ptr(XWasmPtr(f.run([a1, a2, a3, a4, a5, a6, a7, a8]).toInt()));
  }

  /// Binds a `wrap`ed C function taking `9` arguments and returning a plain
  /// (non-struct) value.
  ///
  /// `X` determines the JS->Dart return conversion applied on every call
  /// (see [_conv]); use `void` if the C function returns nothing.
  XF9<X> dwrap9<X>(String name) {
    final f = WasmMemory.wrap(name, 9);
    final c = _conv<X>();
    return (a1, a2, a3, a4, a5, a6, a7, a8, a9) => c(f.run([a1, a2, a3, a4, a5, a6, a7, a8, a9]));
  }

  /// Binds a `wrap`ed C function taking `9` arguments and returning a
  /// pointer, wrapped as `XWasmPtr<X>`.
  ///
  /// `X` is a marker type only.
  XF9<XWasmPtr<X>> pwrap9<X extends XType>(String name) {
    final f = WasmMemory.wrap(name, 9);
    return (a1, a2, a3, a4, a5, a6, a7, a8, a9) => f.run([a1, a2, a3, a4, a5, a6, a7, a8, a9]).asXPtr();
  }

  /// Binds a `wrap`ed C function taking `9` argument and returning a
  /// struct pointer, wrapped as `XStructPtr<X>`.
  XF9<XStructPtr<X>> qwrap9<X extends XStruct<X>>(String name) {
    final f = WasmMemory.wrap(name, 9);
    final struct = XStructDefinitions.of<X>();
    return (a1, a2, a3, a4, a5, a6, a7, a8, a9) => struct.ptr(XWasmPtr(f.run([a1, a2, a3, a4, a5, a6, a7, a8, a9]).toInt()));
  }
}