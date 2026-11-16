part of '../xffi_core.dart';

final _defaultPrint = print;

final class XOutput {
  static Function(Object? object) print = _defaultPrint;
  static Function(Object? object) logInfo = _defaultPrint;
  static Function(Object? object) logWarn = _defaultPrint;
  static Function(Object? object) logError = _defaultPrint;
}