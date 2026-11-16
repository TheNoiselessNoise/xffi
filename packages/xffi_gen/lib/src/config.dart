part of '../xffi_gen.dart';

enum XStructMode { skip, struct, value }

final class XFunctionLayers {
  final bool dart;
  final bool flat;
  final bool ffi;
  final bool wasm;
  const XFunctionLayers({
    this.dart = true,
    this.flat = true,
    this.ffi = true,
    this.wasm = true,
  });
}

sealed class XFieldOverride {
  const XFieldOverride();
}

final class XFixedLength extends XFieldOverride {
  final int length;
  const XFixedLength(this.length);
}

final class XLengthField extends XFieldOverride {
  final String fieldName;
  final bool isExternal;

  const XLengthField(this.fieldName, {this.isExternal = false});
}

final class XLiveList extends XFieldOverride {
  const XLiveList();
}

final class XString extends XFieldOverride {
  final String? length;

  const XString([this.length]);
}

enum XTypedListType {
  Uint8List,
  Int8List,
  Uint16List,
  Int16List,
  Uint32List,
  Int32List,
  Uint64List,
  Int64List,
  Float32List,
  Float64List,
}

final class XOpaque extends XFieldOverride {
  final XTypedListType? asView;

  const XOpaque({
    this.asView,
  });
}

final class XGeneratorConfig {
  final String headerPath;

  final String workDir;
  final String outDir;

  /// [defaultStructMode].
  final Map<String, XStructMode> structModes;
  final XStructMode defaultStructMode;

  final Map<String, XFieldOverride> fieldOverrides;

  /// [defaultFunctionLayers].
  final Map<String, XFunctionLayers> functionLayers;
  final XFunctionLayers defaultFunctionLayers;

  const XGeneratorConfig({
    required this.headerPath,
    required this.workDir,
    required this.outDir,
    this.structModes = const {},
    this.defaultStructMode = .struct,
    this.fieldOverrides = const {},
    this.functionLayers = const {},
    this.defaultFunctionLayers = const XFunctionLayers(),
  });

  XStructMode modeFor(String structName)
    => structModes[structName] ?? defaultStructMode;

  XFieldOverride? overrideFor(String structName, String fieldName)
    => fieldOverrides['$structName.$fieldName'];

  XFunctionLayers layersFor(String funcName)
    => functionLayers[funcName] ?? defaultFunctionLayers;
}