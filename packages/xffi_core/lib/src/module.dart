part of '../xffi_core.dart';

mixin XDisposable {
  /// Registry of callbacks to be executed on [dispose].
  final List<void Function()> _onDisposeFns = [];

  /// Registers [fn] to be called when this module is disposed.
  void listenOnDispose(void Function() fn) => _onDisposeFns.add(fn);

  bool _isDisposed = false;

  /// Calls all registered [onDispose] callbacks and clears them.
  @mustCallSuper
  @nonVirtual
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _onDisposeFns.forEach((f) => f());
    _onDisposeFns.clear();
    onDispose();
  }

  void onDispose() {}
}

/// Base class for all memory modules.
abstract class XModule with XDisposable {
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
  void disposeStructWithOpFreed<X extends XStruct<X>>(
    X struct,
    void Function(XStructPtr<X> ptr) fn,
  ) {
    final ptr = struct.getOpAndDispose();

    try {
      fn(ptr);
    } finally {
      if (ptr.allocationKey case final key?) {
        XTemp.instance.structAlloc<X>().Free(key);
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
  void disposeStructWithOpUnslotted<X extends XStruct<X>>(
    X struct,
    void Function(XStructPtr<X> ptr) fn,
  ) {
    final ptr = struct.getOpAndDispose();

    try {
      fn(ptr);
    } finally {
      if (ptr.allocationKey case final key?) {
        XTemp.instance.structAlloc<X>().Unslot(key);
      }
    }
  }
}