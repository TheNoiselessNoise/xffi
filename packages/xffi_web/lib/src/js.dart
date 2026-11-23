part of '../xffi_web.dart';

BigInt fromJSBigInt(JSBigInt v)
  => .parse(globalContext.callMethod<JSString>('String'.toJS, v).toDart);

JSBigInt toJSBigInt(BigInt v)
  => globalContext.callMethod<JSBigInt>('BigInt'.toJS, v.toString().toJS);

extension BigIntToJSBigInt on BigInt {
  JSBigInt get toJS => toJSBigInt(this);
}

/// JavaScript `window` object.
@JS('window')
external JSWindow get window;

extension type JSWindow._(JSObject _) implements JSObject {
  external JSPromise<JSResponse> fetch(JSAny input, [JSObject? init]);
}

extension type JSResponse._(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

/// JavaScript `console` object.
@JS('console')
external JSConsole get console;

/// Static interop type for the JavaScript `console` object.
@JS()
@staticInterop
final class JSConsole {}

extension JSConsoleExtension on JSConsole {
  @JS('log')
  external void _log(JSAny? value);
  /// Logs a value to the JavaScript console.
  void log(Object? value) => _log(value.jsify());

  @JS('warn')
  external void _warn(JSAny? value);
  /// Logs a warning to the JavaScript console.
  void warn(Object? value) => _warn(value.jsify());

  @JS('error')
  external void _error(JSAny? value);
  /// Logs an error to the JavaScript console.
  void error(Object? value) => _error(value.jsify());
}

/// Returns the enumerable property names of a JavaScript object.
@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject obj);

/// Convenience conversions from JavaScript values to Dart values.
extension JSAnyConversion on JSAny? {

  /// Converts a JavaScript value to a nullable Dart boolean.
  ///
  /// Returns `null` when the value cannot be interpreted as a boolean.
  bool? toNullableBool() {
    if (isUndefinedOrNull) return null;
    if (isA<JSBoolean>()) return (this as JSBoolean).toDart;
    if (isA<JSNumber>()) return (this as JSNumber).toDartInt != 0;
    if (isA<JSString>()) return switch ((this as JSString).toDart.trim().toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => null,
    };
    return null;
  }

  /// Converts a JavaScript value to a Dart boolean.
  ///
  /// Returns [def] when the value cannot be interpreted as a boolean.
  bool toBool([bool def = false]) => toNullableBool() ?? def;

  /// Converts a JavaScript value to a nullable Dart integer.
  int? toNullableInt() {
    if (isUndefinedOrNull) return null;
    if (isA<JSNumber>()) return (this as JSNumber).toDartInt;
    if (isA<JSString>()) return int.tryParse((this as JSString).toDart);
    return null;
  }

  /// Converts a JavaScript value to a Dart integer.
  ///
  /// Returns [def] when the value cannot be interpreted as an integer.
  int toInt([int def = 0]) => toNullableInt() ?? def;

  /// Converts a JavaScript value to a nullable Dart double.
  double? toNullableDouble() {
    if (isUndefinedOrNull) return null;
    if (isA<JSNumber>()) return (this as JSNumber).toDartDouble;
    if (isA<JSString>()) return double.tryParse((this as JSString).toDart);
    return null;
  }

  /// Converts a JavaScript value to a Dart double.
  ///
  /// Returns [def] when the value cannot be interpreted as a double.
  double toDouble([double def = 0.0]) => toNullableDouble() ?? def;

  /// Converts a JavaScript value to a nullable Dart string.
  String? toNullableString() {
    if (isUndefinedOrNull) return null;
    if (isA<JSString>()) return (this as JSString).toDart;
    if (isA<JSNumber>()) return (this as JSNumber).toDartDouble.toString();
    if (isA<JSBoolean>()) return (this as JSBoolean).toDart.toString();
    return null;
  }

  /// Converts a JavaScript value to a Dart string.
  ///
  /// Returns [def] when the value cannot be converted to a string.
  String toDartString([String def = '']) => toNullableString() ?? def;

  /// Converts a JavaScript array to a Dart list.
  List<JSAny?>? toNullableList() {
    if (isUndefinedOrNull) return null;
    if (!isA<JSArray>()) return null;
    final arr = this as JSArray;
    return List.generate(arr.length, (i) => arr[i]);
  }

  /// Converts a JavaScript array to a Dart list.
  ///
  /// Returns an empty list when the value is not a JavaScript array.
  List<JSAny?> toList() => toNullableList() ?? [];

  /// Converts a JavaScript object to a Dart map.
  Map<String, JSAny?>? toNullableMap() {
    if (isUndefinedOrNull) return null;
    if (!isA<JSObject>() || isA<JSArray>()) return null;
    final obj = this as JSObject;
    final keys = _objectKeys(obj).toDart;
    return {
      for (final k in keys) k.toDart: obj.getProperty(k),
    };
  }

  /// Converts a JavaScript object to a Dart map.
  ///
  /// Returns an empty map when the value is not a JavaScript object.
  Map<String, JSAny?> toMap() => toNullableMap() ?? {};

  /// Whether this value is neither JavaScript `undefined` nor `null`.
  bool get isDefined => !isUndefinedOrNull;
}

extension XJSFunctionUtilExtension on JSFunction {
  @JS('apply')
  external JSAny? _applyFn(JSAny? thisArg, JSArray<JSAny?> args);

  JSAny? run([List<JSAny?> args = const []]) => _applyFn(null, args.toJS);
}