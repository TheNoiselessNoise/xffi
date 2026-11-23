import 'package:xffi_core/xffi_core.dart';

/// See [XTemp.structAlloc].
XStructAlloc<D> structAllocator<D extends XStruct<D>>()
  => XTemp.instance.structAlloc<D>();

/// See [XTemp.structAllocUntyped].
XStructAlloc structAllocatorUntyped(Object type)
  => XTemp.instance.structAllocUntyped(type);

/// See [XTemp.scalarAlloc].
XScalarAlloc scalarAllocator<R extends XType>([Object? type])
  => XTemp.instance.scalarAlloc<R>(type);

/// See [XStructDefinitions.of].
XStructDef<D> structType<D extends XStruct<D>>()
  => XStructDefinitions.of<D>();

/// See [XStructDefinitions.ofUntyped].
XStructDef structTypeUntyped(Object type)
  => XStructDefinitions.ofUntyped(type);

/// See [XUtils.realloc].
XPtr<XVoid> realloc(XPtr oldPtr, int oldSize, int newSize)
  => XUtils.realloc(oldPtr, oldSize, newSize);

/// See [XUtils.memset].
void memset(XPtr ptr, int value, int size)
  => XUtils.memset(ptr, value, size);

/// See [XUtils.memcpy].
void memcpy(XPtr dest, XPtr src, int n)
  => XUtils.memcpy(dest, src, n);

/// See [XUtils.memcmp].
int memcmp(XPtr a, XPtr b, int n)
  => XUtils.memcmp(a, b, n);

/// See [XUtils.strlen].
int strlen(XPtr ptr)
  => XUtils.strlen(ptr);

/// See [XUtils.strnlen].
int strnlen(XPtr ptr, int maxLen)
  => XUtils.strnlen(ptr, maxLen);

/// See [XUtils.strcmp].
int strcmp(XPtr a, XPtr b)
  => XUtils.strcmp(a, b);

/// See [XUtils.strcpy].
void strcpy(XPtr dest, XPtr src)
  => XUtils.strcpy(dest, src);

/// See [XUtils.strncpy].
void strncpy(XPtr dest, XPtr src, int n)
  => XUtils.strncpy(dest, src, n);

/// See [XUtils.strncat].
void strncat(XPtr dest, XPtr src, int n)
  => XUtils.strncat(dest, src, n);

/// See [XUtils.strstr].
XPtr<XVoid> strstr(XPtr haystack, XPtr needle)
  => XUtils.strstr(haystack, needle);

/// See [XUtils.swap8].
int swap8(int v) => XUtils.swap8(v);

/// See [XUtils.swap16].
int swap16(int v) => XUtils.swap16(v);

/// See [XUtils.swap32].
int swap32(int v) => XUtils.swap32(v);

/// See [XUtils.swap64].
int swap64(int v) => XUtils.swap64(v);

extension StringToXPtr on String {
  XPtr<XChar> get toC => XTemp.instance.String$.Value(this);
}