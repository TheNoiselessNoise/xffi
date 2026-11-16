part of '../xffi_core.dart';

/// Global configuration for memory.
///
/// Provides configurable limits and defaults used by the library's temporary
/// memory allocators, struct handling, and other integration.
///
/// Unless otherwise documented, values should be configured before initializing the backend.
final class XConfig {
  /// The number of string slots to pre-allocate.
  ///
  /// Defaults to `4`. Increase this if your frame logic needs to pass
  /// more than 4 temporary strings in a single tick.
  static int tempStringSlots = 4;

  /// Maximum size, in bytes, of a struct supported by internal scratch buffers.
  ///
  /// These buffers are used for fast byte-level equality checks of structs.
  /// Increase this if a struct larger than the default limit needs to be
  /// compared using `==`.
  static int maxStructByteSize = 1024;

  /// Maximum number of simultaneously tracked temporary allocations per
  /// temporary allocator.
  ///
  /// Defaults to `1024`. This acts as a safety limit against accidentally
  /// creating an unbounded number of temporary allocation slots.
  static int maxTrackedAllocations = 1024;
}