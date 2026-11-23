import 'dart:typed_data';
import 'package:xffi_core/xffi_core.dart';

// Exports everything that can be shared across Dart and Flat layers.

XTemp get _$ => XTemp.instance;

/// See [XTemp.TypedDataList$].
final XTypedDataListAlloc TypedDataList$ = _$.TypedDataList$;

/// See [XTemp.String$].
final XStringAlloc String$ = _$.String$;

/// [XSize] allocator.
final XScalarAlloc<int, XSize> RSize$ = _$.scalarAlloc<XSize>() as XScalarAlloc<int, XSize>;

/// [XSsize] allocator.
final XScalarAlloc<int, XSsize> RSsize$ = _$.scalarAlloc<XSsize>() as XScalarAlloc<int, XSsize>;

/// [XIntPtr] allocator.
final XScalarAlloc<int, XIntPtr> RIntPtr$ = _$.scalarAlloc<XIntPtr>() as XScalarAlloc<int, XIntPtr>;

/// [XUintPtr] allocator.
final XScalarAlloc<int, XUintPtr> RUintPtr$ = _$.scalarAlloc<XUintPtr>() as XScalarAlloc<int, XUintPtr>;

/// [XPtrDiff] allocator.
final XScalarAlloc<int, XPtrDiff> RPtrDiff$ = _$.scalarAlloc<XPtrDiff>() as XScalarAlloc<int, XPtrDiff>;

/// [XBool] allocator.
final XScalarAlloc<bool, XBool> Bool$ = _$.scalarAlloc<XBool>() as XScalarAlloc<bool, XBool>;

/// [XInt8] allocator.
final XScalarIntAlloc<Int8List, XInt8> Int8$ = _$.scalarAlloc<XInt8>() as XScalarIntAlloc<Int8List, XInt8>;

/// [XUint8] allocator.
final XScalarIntAlloc<Uint8List, XUint8> Uint8$ = _$.scalarAlloc<XUint8>() as XScalarIntAlloc<Uint8List, XUint8>;

/// [XInt16] allocator.
final XScalarIntAlloc<Int16List, XInt16> Int16$ = _$.scalarAlloc<XInt16>() as XScalarIntAlloc<Int16List, XInt16>;

/// [XUint16] allocator.
final XScalarIntAlloc<Uint16List, XUint16> Uint16$ = _$.scalarAlloc<XUint16>() as XScalarIntAlloc<Uint16List, XUint16>;

/// [XInt32] allocator.
final XScalarIntAlloc<Int32List, XInt32> Int32$ = _$.scalarAlloc<XInt32>() as XScalarIntAlloc<Int32List, XInt32>;

/// [XUint32] allocator.
final XScalarIntAlloc<Uint32List, XUint32> Uint32$ = _$.scalarAlloc<XUint32>() as XScalarIntAlloc<Uint32List, XUint32>;

/// [XInt64] allocator.
final XScalarIntAlloc<Int64List, XInt64> Int64$ = _$.scalarAlloc<XInt64>() as XScalarIntAlloc<Int64List, XInt64>;

/// [XUint64] allocator.
final XScalarIntAlloc<Uint64List, XUint64> Uint64$ = _$.scalarAlloc<XUint64>() as XScalarIntAlloc<Uint64List, XUint64>;

/// [XFloat32] allocator.
final XScalarFloatAlloc<Float32List, XFloat32> Float32$ = _$.scalarAlloc<XFloat32>() as XScalarFloatAlloc<Float32List, XFloat32>;

/// [XFloat64] allocator.
final XScalarFloatAlloc<Float64List, XFloat64> Float64$ = _$.scalarAlloc<XFloat64>() as XScalarFloatAlloc<Float64List, XFloat64>;

/// [XLong] allocator.
final XScalarIntAlloc<Int64List, XLong> Long$ = _$.scalarAlloc<XLong>() as XScalarIntAlloc<Int64List, XLong>;

/// [XUnsignedLong] allocator.
final XScalarIntAlloc<Uint64List, XUnsignedLong> UnsignedLong$ = _$.scalarAlloc<XUnsignedLong>() as XScalarIntAlloc<Uint64List, XUnsignedLong>;

/// [XLongLong] allocator.
final XScalarIntAlloc<Int64List, XLongLong> LongLong$ = _$.scalarAlloc<XLongLong>() as XScalarIntAlloc<Int64List, XLongLong>;

/// [XUnsignedLongLong] allocator.
final XScalarIntAlloc<Uint64List, XUnsignedLongLong> UnsignedLongLong$ = _$.scalarAlloc<XUnsignedLongLong>() as XScalarIntAlloc<Uint64List, XUnsignedLongLong>;

// scalar aliases

/// [XChar] allocator.
final XScalarIntAlloc<Int8List, XChar> Char$ = Int8$;

/// [XUnsignedChar] allocator.
final XScalarIntAlloc<Uint8List, XUnsignedChar> UnsignedChar$ = Uint8$;

/// [XShort] allocator.
final XScalarIntAlloc<Int16List, XShort> Short$ = Int16$;

/// [XUnsignedShort] allocator.
final XScalarIntAlloc<Uint16List, XUnsignedShort> UnsignedShort$ = Uint16$;

/// [XInt] allocator.
final XScalarIntAlloc<Int32List, XInt> Int$ = Int32$;

/// [XUnsignedInt] allocator.
final XScalarIntAlloc<Uint32List, XUnsignedInt> UnsignedInt$ = Uint32$;

/// [XFloat] allocator.
final XScalarFloatAlloc<Float32List, XFloat> Float$ = Float32$;

/// [XDouble] allocator.
final XScalarFloatAlloc<Float64List, XDouble> Double$ = Float64$;