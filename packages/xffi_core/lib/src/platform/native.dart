import 'dart:io';
import 'package:xffi_core/xffi_core.dart';

/// The platform selected at compile time.
MemoryPlatform get currentMemoryPlatform {
  if (Platform.isAndroid) return .android;
  if (Platform.isLinux) return .linux;
  if (Platform.isMacOS) return .macOS;
  if (Platform.isIOS) return .iOS;
  if (Platform.isWindows) return .windows;
  if (Platform.isFuchsia) return .fuchsia;
  throw UnsupportedError('No xffi platform implementation available for ${Platform.operatingSystem} platform');
}