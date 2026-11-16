part of '../xffi_core.dart';

/// Supported runtime platforms.
enum MemoryPlatform {
  /// linux
  linux,
  /// windows
  windows,
  /// macOS
  macOS,
  /// web
  web,
  /// android
  android,
  /// iOS
  iOS,
  /// fuchsia
  fuchsia,
}

/// All available platform targets.
enum MemoryPlatformTarget {
  /// androidArm
  androidArm,
  /// androidArm64
  androidArm64,
  /// androidIA32
  androidIA32,
  /// androidX64
  androidX64,
  /// androidRiscv64
  androidRiscv64,
  /// fuchsiaArm64
  fuchsiaArm64,
  /// fuchsiaX64
  fuchsiaX64,
  /// fuchsiaRiscv64
  fuchsiaRiscv64,
  /// iosArm
  iosArm,
  /// iosArm64
  iosArm64,
  /// iosArm64e
  iosArm64e,
  /// iosX64
  iosX64,
  /// linuxArm
  linuxArm,
  /// linuxArm64
  linuxArm64,
  /// linuxIA32
  linuxIA32,
  /// linuxX64
  linuxX64,
  /// linuxRiscv32
  linuxRiscv32,
  /// linuxRiscv64
  linuxRiscv64,
  /// macosArm64
  macosArm64,
  /// macosArm64e
  macosArm64e,
  /// macosX64
  macosX64,
  /// windowsArm64
  windowsArm64,
  /// windowsIA32
  windowsIA32,
  /// windowsX64
  windowsX64,

  /// web (special)
  web,

  /// unknown
  unknown,
}

/// All supported types of platforms.
enum MemoryPlatformType {
  /// Native Dart VM / FFI backend.
  native,

  /// Web / WASM backend.
  web,
}