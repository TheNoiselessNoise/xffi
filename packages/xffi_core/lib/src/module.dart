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