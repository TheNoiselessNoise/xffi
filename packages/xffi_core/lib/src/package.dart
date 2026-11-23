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

  /// If this module has debug log enabled.
  bool _debugEnabled = false;

  /// Enables or disables debug logging for this module.
  void debug(bool v) => _debugEnabled = v;

  /// If this module has debug log (with time) enabled.
  bool _debugTime = false;

  /// Enables or disables per-call timing output alongside debug logs.
  void debugTime(bool v) => _debugTime = true;

  /// Filters for filtering debug messages.
  final List<bool Function(String)> _debugFilters = [];

  /// Adds a predicate that gates debug output. Only messages satisfying at least one filter are logged.
  void debugFilter(bool Function(String) filter) => _debugFilters.add(filter);

  /// Returns `true` if no filters are registered, or if any registered filter matches [message].
  bool _matchesFilters(String message) => _debugFilters.isEmpty || _debugFilters.any((f) => f(message));

  /// Logs [message] at info level if debug is enabled and [message] passes all filters.
  void debugInfo(String message) { if (_debugEnabled && _matchesFilters(message)) XOutput.logInfo(message); }

  /// Logs [message] at warn level if debug is enabled and [message] passes all filters.
  void debugWarn(String message) { if (_debugEnabled && _matchesFilters(message)) XOutput.logWarn(message); }

  /// Logs [message] at error level if debug is enabled and [message] passes all filters.
  void debugError(String message) { if (_debugEnabled && _matchesFilters(message)) XOutput.logError(message); }

  /// Executes [fn], logs its elapsed time under [label], and rethrows any exception
  /// with timing info attached.
  T debugTimeIt<T>(String label, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      final result = fn();
      sw.stop();
      XOutput.logInfo('$label: ${sw.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      sw.stop();
      XOutput.logError(label);
      XOutput.logError('THREW after ${sw.elapsedMilliseconds}ms : $e');
      rethrow;
    }
  }

  /// Executes [f], logging its label (and optionally timing it) when debug is enabled
  /// and the label passes all filters.
  T debugRun<T>(String Function() name, T Function() f) {
    if (_debugEnabled) {
      final label = name();
      if (_matchesFilters(label)) {
        if (_debugTime) return debugTimeIt(label, f);
        XOutput.logInfo(label);
      }
    }
    return f();
  }

  /// Disposes [struct], invokes [fn] with its underlying pointer, and then frees
  /// the temporary allocation backing the pointer, if any.
  ///
  /// The allocation is freed after [fn] completes, including when [fn] throws.
  /// This is intended for APIs where the external call does not take ownership
  /// of the underlying memory.
  void disposeStructWithOpFreed<Y extends XStruct<Y>>(
    Y struct,
    void Function(XStructPtr<Y> ptr) fn,
  ) {
    final ptr = struct.getOpAndDispose();

    try {
      fn(ptr);
    } finally {
      if (ptr.allocationKey case final key?) {
        XTemp.instance.structAlloc<Y>().Free(key);
      } else {
        ptr.free();
      }
    }
  }

  /// Disposes [struct], invokes [fn] with its underlying pointer, and then
  /// unslots the temporary allocation backing the pointer, if any.
  ///
  /// The allocation is removed from the temporary allocator without freeing its
  /// underlying memory. This is intended for APIs where the external call takes
  /// responsibility for freeing the memory.
  ///
  /// The allocation is unslotted after [fn] completes, including when [fn]
  /// throws.
  void disposeStructWithOpUnslotted<Y extends XStruct<Y>>(
    Y struct,
    void Function(XStructPtr<Y> ptr) fn,
  ) {
    final ptr = struct.getOpAndDispose();

    try {
      fn(ptr);
    } finally {
      if (ptr.allocationKey case final key?) {
        XTemp.instance.structAlloc<Y>().Unslot(key);
      }
    }
  }
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

  /// Enables or disables debug logging across all modules and the temp allocator.
  void debugEverything(bool debug) {
    registeredModules.forEach((d) => d.debug(debug));
    XTemp.instance.debugFree(debug);
    XTemp.instance.debugSync(debug);
  }

  /// Executes [fn], logs its elapsed time under [label], and rethrows any exception
  /// with timing info attached.
  T timeIt<T>(String label, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      final result = fn();
      sw.stop();
      XOutput.logInfo('$label: ${sw.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      sw.stop();
      XOutput.logError(label);
      XOutput.logError('THREW after ${sw.elapsedMilliseconds}ms : $e');
      rethrow;
    }
  }

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

  /// Prints the current stack trace for debugging.
  Null stackTrace({String? title, bool exit = false}) {
    if (title != null) XOutput.logInfo(title);
    XOutput.logInfo(StackTrace.current);
    if (exit) throw '';
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