part of '../xffi_core.dart';

/// Root of the temporary allocator hierarchy.
///
/// Owns the set of typed allocators (e.g. [XInt8], [XFloat32], struct allocators)
/// and governs the lifetime of all slots allocated.
/// 
/// All allocated slots are freed on [dispose].
final class XTemp {
  static XTemp? _instance;
  static XTemp get instance => _instance ??= XTemp._();

  XTemp._() { _initScalarAllocators(); }

  /// Monotonically increasing ID.
  int _currentId = 0;

  /// Returns a monotonically increasing ID, used to generate unique slot keys.
  int nextId() => _currentId++;

  /// If logging of slot deallocation events is enabled.
  bool _debugFreeEnabled = false;

  /// Enables or disables logging of slot deallocation events.
  void debugFree(bool v) => _debugFreeEnabled = v;

  /// Logs [message] if free debugging is enabled.
  void debugFreeInfo(String message) { if (_debugFreeEnabled) XOutput.logInfo(message); }

  /// If logging of struct sync-back events is enabled.
  bool _debugSyncEnabled = false;

  /// Enables or disables logging of struct sync-back events.
  void debugSync(bool v) => _debugSyncEnabled = v;

  /// Logs [message] if sync debugging is enabled.
  void debugSyncInfo(String message) { if (_debugSyncEnabled) XOutput.logInfo(message); }

  // special

  late final XTypedDataListAlloc TypedDataList$ = .new();
  late final XStringAlloc String$ = .new();
  late final XPtrAlloc _pointerAllocator = .new();

  // scalars

  final Map<Type, XScalarAlloc> _scalarAllocators = {};

  void _initScalarAllocators() {
    XScalarTypes.register<XSize>(const XSize());
    XScalarTypes.register<XSsize>(const XSsize());
    XScalarTypes.register<XIntPtr>(const XIntPtr());
    XScalarTypes.register<XUintPtr>(const XUintPtr());
    XScalarTypes.register<XPtrDiff>(const XPtrDiff());

    for (final a in <XScalarAlloc>[
      XScalarAlloc<int, XSize>(),
      XScalarAlloc<int, XSsize>(),
      XScalarAlloc<int, XIntPtr>(),
      XScalarAlloc<int, XUintPtr>(),
      XScalarAlloc<int, XPtrDiff>(),
    ]) _scalarAllocators[a._memoryType] = a;

    XScalarTypes.register<XBool>(const XBool());
    XScalarTypes.register<XInt8>(const XInt8());
    XScalarTypes.register<XUint8>(const XUint8());
    XScalarTypes.register<XInt16>(const XInt16());
    XScalarTypes.register<XUint16>(const XUint16());
    XScalarTypes.register<XInt32>(const XInt32());
    XScalarTypes.register<XUint32>(const XUint32());
    XScalarTypes.register<XInt64>(const XInt64());
    XScalarTypes.register<XUint64>(const XUint64());
    XScalarTypes.register<XFloat32>(const XFloat32());
    XScalarTypes.register<XFloat64>(const XFloat64());

    for (final a in <XScalarAlloc>[
      XScalarAlloc<bool, XBool>(),
      XScalarIntAlloc<Int8List, XInt8>(),
      XScalarIntAlloc<Uint8List, XUint8>(),
      XScalarIntAlloc<Int16List, XInt16>(),
      XScalarIntAlloc<Uint16List, XUint16>(),
      XScalarIntAlloc<Int32List, XInt32>(),
      XScalarIntAlloc<Uint32List, XUint32>(),
      XScalarIntAlloc<Int64List, XInt64>(),
      XScalarIntAlloc<Uint64List, XUint64>(),
      XScalarFloatAlloc<Float32List, XFloat32>(),
      XScalarFloatAlloc<Float64List, XFloat64>(),
    ]) _scalarAllocators[a._memoryType] = a;

    XScalarTypes.register<XLong>(const XLong());
    XScalarTypes.register<XUnsignedLong>(const XUnsignedLong());
    XScalarTypes.register<XLongLong>(const XLongLong());
    XScalarTypes.register<XUnsignedLongLong>(const XUnsignedLongLong());

    for (final a in <XScalarAlloc>[
      XScalarIntAlloc<Int64List, XLong>(),
      XScalarIntAlloc<Uint64List, XUnsignedLong>(),
      XScalarIntAlloc<Int64List, XLongLong>(),
      XScalarIntAlloc<Uint64List, XUnsignedLongLong>(),
    ]) _scalarAllocators[a._memoryType] = a;
  }

  XScalarAlloc _scalarLookup(Type t)
    => _scalarAllocators[t] ?? (throw StateError('No scalar allocator for $t'));

  /// Lookup by either passed [type] ([Type], [XType]) or via generic param [Y].
  XScalarAlloc scalarAlloc<Y extends XType>([Object? type])
    => _scalarLookup(switch (type) {
      null => Y,
      Type t => t,
      XType r => r.runtimeType,
      _ => throw ArgumentError.value(type, 'type', 'expected Type or MemoryType'),
    });

  final Map<Type, XStructAlloc> _structAllocators = {};

  XStructAlloc structAllocUntyped(Object type) {
    if (type is XStructDef<XDynStruct>) {
      return _structAllocators[type.baseType] ??= type._allocator;
    }
    final st = XStructDefinitions.ofUntyped(type);
    return _structAllocators[st.baseType] ??= st._allocator;
  }

  XStructAlloc<X> structAlloc<X extends XStruct<X>>()
    => structAllocUntyped(X) as XStructAlloc<X>;
  
  /// Frees all allocators.
  @mustCallSuper
  void dispose() {
    debugFreeInfo('Freeing built-in ${_scalarAllocators.length + 2} scalar allocators...');
    String$.dispose();
    _pointerAllocator.dispose();
    _scalarAllocators.values.forEach((a) => a.dispose());

    if (_structAllocators.isNotEmpty) {
      debugFreeInfo('Freeing ${_structAllocators.length} struct allocators...');
      _structAllocators.values.forEach((a) => a.dispose());
    }
  }
}