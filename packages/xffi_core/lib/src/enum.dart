part of '../xffi_core.dart';

/// Adds ordered comparison operators to enums that expose a raw [value],
/// mirroring C enum integer semantics.
mixin XEnum on Enum {
  /// The underlying native integer value.
  int get value;

  bool operator <(XEnum other) => value < other.value;
  bool operator >(XEnum other) => value > other.value;
  bool operator <=(XEnum other) => value <= other.value;
  bool operator >=(XEnum other) => value >= other.value;
}