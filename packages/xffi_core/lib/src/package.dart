part of '../xffi_core.dart';

/// Base class for all Imgui module wrappers, providing debug logging, lifecycle
/// management, and sync control tied to a [XPackage] context [pkg].
abstract class XPackageModule<X extends XPackage> with XDisposable {
  final X pkg;

  XPackageModule(this.pkg);

  /// If this module was loaded.
  bool _isLoaded = false;

  void _doLoad() {
    if (_isLoaded) return;
    _isLoaded = true;
    load();
  }

  /// Override to perform one-time module initialization.
  void load() {}
}

/// Root class for a fully initialized one memory context, exposing all it's modules,
/// extensions, lifecycle management, and possible forwarded constants and/or functions.
abstract class XPackage with XDisposable {
  final bool _silent;
  void Function()? onBoot;

  XPackage({
    this._silent = false,
    this.onBoot,
  });

  bool _booted = false;

  @nonVirtual
  void boot() {
    if (_booted) return;
    _booted = true;
    onBoot?.call();
  }

  /// All currently registered modules.
  List<XPackageModule> get registeredModules => _registeredModules.values.toList();

  /// Registry of registered modules.
  final Map<Type, XPackageModule> _registeredModules = {};

  /// Registers [module], calls [XPackageModule.load] on it, and returns it.
  /// Throws [StateError] if a module of the same type is already registered.
  T registerModule<T extends XPackageModule>(T module) {
    if (!_silent) XOutput.logInfo('Registering $T');

    if (_registeredModules.containsKey(T)) {
      throw StateError("Module '$T' is already registered!");
    }

    _registeredModules[T] = module;
    module._doLoad();
    return module;
  }

  /// Returns the registered module of type [T]. Throws if not registered.
  T module<T extends XPackageModule>() {
    final module = _registeredModules[T];

    if (module == null) {
      throw StateError("Module '$T' is not registered!");
    }

    return module as T;
  }

  /// Disposes a provided module. Does **not** remove it from the registry.
  void _disposeModule(XPackageModule module) {
    if (!_silent) XOutput.logInfo('Disposing ${module.runtimeType}');
    module.dispose();
  }

  /// Disposes all registered modules.
  @override
  @mustCallSuper
  void onDispose() {
    registeredModules.forEach(_disposeModule);
    XScratch.dispose();
  }
}