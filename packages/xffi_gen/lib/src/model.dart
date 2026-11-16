part of '../xffi_gen.dart';

sealed class XDecl {
  final String name;
  const XDecl(this.name);
}

final class XStructDecl extends XDecl {
  final List<XFieldDecl> fields;
  const XStructDecl(super.name, this.fields);
}

final class XEnumDecl extends XDecl {
  final List<XEnumValue> values;
  const XEnumDecl(super.name, this.values);
}

final class XEnumValue {
  final String name;
  final int value;
  const XEnumValue(this.name, this.value);
}

final class XFuncDecl extends XDecl {
  final XTypeRef returnType;
  final List<XParamDecl> params;
  const XFuncDecl(super.name, this.returnType, this.params);
}

final class XParamDecl {
  final String name;
  final XTypeRef type;
  const XParamDecl(this.name, this.type);
}

final class XGlobalDecl extends XDecl {
  final XTypeRef type;
  const XGlobalDecl(super.name, this.type);
}

final class XFieldDecl {
  final String name;
  final XTypeRef type;
  XFieldKind? kind;
  XFieldDecl(this.name, this.type, {this.kind});
}

enum XFieldKind { scalar, nestedStruct, fixedArray, dynamicArray, functionPointer, opaquePointer }

sealed class XTypeRef {
  const XTypeRef();
}

final class XPrimitiveType extends XTypeRef {
  final String dartName; // e.g. "int", "double", "bool"
  const XPrimitiveType(this.dartName);
}

final class XNamedType extends XTypeRef {
  final String name; // refers to another StructDecl/EnumDecl by name
  const XNamedType(this.name);
}

final class XPointerType extends XTypeRef {
  final XTypeRef pointee;
  const XPointerType(this.pointee);
}

final class XFixedArrayType extends XTypeRef {
  final XTypeRef element;
  final int length;
  const XFixedArrayType(this.element, this.length);
}

final class XVoidType extends XTypeRef {
  const XVoidType();
}