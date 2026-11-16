import 'dart:typed_data';
import 'package:xffi_core/xffi_core.dart';

// Exports everything that can be shared across Dart and Flat layers.

XTemp get _$ => XTemp.instance;

/// See [XTemp.TypedDataList$].
XTypedDataListAlloc get TypedDataList$ => _$.TypedDataList$;

/// See [XTemp.String$].
XStringAlloc get String$ => _$.String$;

/// Allocator for type [XSize].
XScalarAlloc<int, XSize> get RSize$ => _$.scalarAlloc<XSize>() as XScalarAlloc<int, XSize>;

/// Allocator for type [XSsize].
XScalarAlloc<int, XSsize> get RSsize$ => _$.scalarAlloc<XSsize>() as XScalarAlloc<int, XSsize>;

/// Allocator for type [XIntPtr].
XScalarAlloc<int, XIntPtr> get RIntPtr$ => _$.scalarAlloc<XIntPtr>() as XScalarAlloc<int, XIntPtr>;

/// Allocator for type [XUintPtr].
XScalarAlloc<int, XUintPtr> get RUintPtr$ => _$.scalarAlloc<XUintPtr>() as XScalarAlloc<int, XUintPtr>;

/// Allocator for type [XPtrDiff].
XScalarAlloc<int, XPtrDiff> get RPtrDiff$ => _$.scalarAlloc<XPtrDiff>() as XScalarAlloc<int, XPtrDiff>;

/// Allocator for type [XBool].
XScalarAlloc<bool, XBool> get Bool$ => _$.scalarAlloc<XBool>() as XScalarAlloc<bool, XBool>;

/// Allocator for type [XInt8].
XScalarIntAlloc<Int8List, XInt8> get Int8$ => _$.scalarAlloc<XInt8>() as XScalarIntAlloc<Int8List, XInt8>;

/// Allocator for type [XUint8].
XScalarIntAlloc<Uint8List, XUint8> get Uint8$ => _$.scalarAlloc<XUint8>() as XScalarIntAlloc<Uint8List, XUint8>;

/// Allocator for type [XInt16].
XScalarIntAlloc<Int16List, XInt16> get Int16$ => _$.scalarAlloc<XInt16>() as XScalarIntAlloc<Int16List, XInt16>;

/// Allocator for type [XUint16].
XScalarIntAlloc<Uint16List, XUint16> get Uint16$ => _$.scalarAlloc<XUint16>() as XScalarIntAlloc<Uint16List, XUint16>;

/// Allocator for type [XInt32].
XScalarIntAlloc<Int32List, XInt32> get Int32$ => _$.scalarAlloc<XInt32>() as XScalarIntAlloc<Int32List, XInt32>;

/// Allocator for type [XUint32].
XScalarIntAlloc<Uint32List, XUint32> get Uint32$ => _$.scalarAlloc<XUint32>() as XScalarIntAlloc<Uint32List, XUint32>;

/// Allocator for type [XInt64].
XScalarIntAlloc<Int64List, XInt64> get Int64$ => _$.scalarAlloc<XInt64>() as XScalarIntAlloc<Int64List, XInt64>;

/// Allocator for type [XUint64].
XScalarIntAlloc<Uint64List, XUint64> get Uint64$ => _$.scalarAlloc<XUint64>() as XScalarIntAlloc<Uint64List, XUint64>;

/// Allocator for type [XFloat32].
XScalarFloatAlloc<Float32List, XFloat32> get Float32$ => _$.scalarAlloc<XFloat32>() as XScalarFloatAlloc<Float32List, XFloat32>;

/// Allocator for type [XFloat64].
XScalarFloatAlloc<Float64List, XFloat64> get Float64$ => _$.scalarAlloc<XFloat64>() as XScalarFloatAlloc<Float64List, XFloat64>;

/// Allocator for type [XLong].
XScalarIntAlloc<Int64List, XLong> get Long$ => _$.scalarAlloc<XLong>() as XScalarIntAlloc<Int64List, XLong>;

/// Allocator for type [XUnsignedLong].
XScalarIntAlloc<Uint64List, XUnsignedLong> get UnsignedLong$ => _$.scalarAlloc<XUnsignedLong>() as XScalarIntAlloc<Uint64List, XUnsignedLong>;

/// Allocator for type [XLongLong].
XScalarIntAlloc<Int64List, XLongLong> get LongLong$ => _$.scalarAlloc<XLongLong>() as XScalarIntAlloc<Int64List, XLongLong>;

/// Allocator for type [XUnsignedLongLong].
XScalarIntAlloc<Uint64List, XUnsignedLongLong> get UnsignedLongLong$ => _$.scalarAlloc<XUnsignedLongLong>() as XScalarIntAlloc<Uint64List, XUnsignedLongLong>;

// scalar aliases

/// Allocator for type [XChar].
XScalarIntAlloc<Int8List, XChar> get Char$ => Int8$;

/// Allocator for type [XUnsignedChar].
XScalarIntAlloc<Uint8List, XUnsignedChar> get UnsignedChar$ => Uint8$;

/// Allocator for type [XShort].
XScalarIntAlloc<Int16List, XShort> get Short$ => Int16$;

/// Allocator for type [XUnsignedShort].
XScalarIntAlloc<Uint16List, XUnsignedShort> get UnsignedShort$ => Uint16$;

/// Allocator for type [XInt].
XScalarIntAlloc<Int32List, XInt> get Int$ => Int32$;

/// Allocator for type [XUnsignedInt].
XScalarIntAlloc<Uint32List, XUnsignedInt> get UnsignedInt$ => Uint32$;

/// Allocator for type [XFloat].
XScalarFloatAlloc<Float32List, XFloat> get Float$ => Float32$;

/// Allocator for type [XDouble].
XScalarFloatAlloc<Float64List, XDouble> get Double$ => Float64$;