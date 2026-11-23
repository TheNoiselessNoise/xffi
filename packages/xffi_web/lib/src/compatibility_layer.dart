part of '../xffi_web.dart';

abstract class WasmCompatibilityLayer {
  ByteBuffer buf();
  int malloc(int size);
  int calloc(int nmemb, int size);
  void free(int ptr);
  int memset(int ptr, int value, int size);
  void stringToUTF8(String str, int ptr, int maxLen);
  int lengthBytesUTF8(String str);
  int addFunction(JSFunction func, String signature);
  void removeFunction(int index);
  int getAddress(String name);
  JSFunction wrap(String name, int arity);
  JSFunction swrap(String name, int arity);
  JSFunction dwrap(String name, [List<String> argTypes = const [], String? returnType]);
  XWasmPtr<X> symbol<X extends XType>(String name) => .new(getAddress(name));
  void print(List<Object?> values) => core.print(values.map((o) => o.toString()).join(' ').toJS);
}