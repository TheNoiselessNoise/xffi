import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'shared.dart';

// Unlike vanilla JavaScript, Dart's try/catch cannot reliably catch WASM
// traps (e.g. calling a removed function or invoking a function with an
// incompatible signature). WASM traps are runtime-level exceptions that
// are not necessarily propagated through Dart's exception handling.
//
// Instead, delegate the call to a JavaScript helper (`tryCall`), where a
// native JS try/catch can intercept the trap and return its result.
({bool ok, String? error}) tryCall(JSFunction function, List<JSAny?> args) {
  final result = globalContext.callMethod<JSObject>('tryCall'.toJS, function, args.toJS);
  final ok = result.getProperty<JSBoolean>('ok'.toJS).toDart;
  return (ok: ok, error: ok ? null : result.getProperty<JSString>('error'.toJS).toDart);
}

void main() => start(trapCall: tryCall);
