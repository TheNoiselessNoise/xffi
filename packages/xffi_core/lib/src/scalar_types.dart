part of '../xffi_core.dart';

/// Registry of [XType]s
final class XScalarTypes {
  XScalarTypes._();
  
  static final Map<Type, XType> _types = {};
  static final Map<String, XType> _fromString = {};

  static bool exists<X extends XType>()
    => _types.containsKey(X);

  /// Registers a [XType] under the key [X].
  static void register<X extends XType>(X type) {
    if (exists<X>()) {
      throw StateError('MemoryType for $X is already registered.');
    }
    _types[X] = type;
    _fromString[X.toString()] = type;
  }

  /// Gets the [XType] (either by type [X] directly or by infering type from [value]).
  /// 
  /// If it does not exist, throws [StateError].
  static X of<X extends XType>([Object? value]) {
    if (value case X found) return found;

    late XType type;
    if (value is Type) {
      final found = _types[value];
      if (found == null) {
        throw StateError('No scalar registered for passed type: $value.');
      }
      type = found;
    } else if (value is String) {
      final found = _fromString[value];
      if (found == null) {
        throw StateError('No scalar registered for String value: $value.');
      }
      type = found;
    } else {
      final found = _types[X];
      if (found == null) {
        throw StateError('No scalar registered for: $X.');
      }
      type = found;
    }

    return type as X;
  }
}