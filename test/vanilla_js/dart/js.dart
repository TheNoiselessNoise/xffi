import 'dart:js_interop';
import 'package:xffi_web_vanilla/xffi_web_vanilla.dart';
import 'shared.dart';

({bool ok, String? error}) tryCall(JSFunction function, List<JSAny?> args) {
  try {
    function.run(args);
    return (ok: true, error: null);
  } catch (error) {
    return (ok: false, error: '$error');
  }
}

void main() => start(trapCall: tryCall);
