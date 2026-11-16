import 'dart:ffi';
import 'package:xffi_core/xffi_core.dart';

/// The platform target selected at compile time.
MemoryPlatformTarget get currentMemoryPlatformTarget => switch (Abi.current()) {
  .androidArm => .androidArm,
  .androidArm64 => .androidArm64,
  .androidIA32 => .androidIA32,
  .androidX64 => .androidX64,
  .androidRiscv64 => .androidRiscv64,
  .fuchsiaArm64 => .fuchsiaArm64,
  .fuchsiaX64 => .fuchsiaX64,
  .fuchsiaRiscv64 => .fuchsiaRiscv64,
  .iosArm => .iosArm,
  .iosArm64 => .iosArm64,
  // .iosArm64e => .iosArm64e,
  .iosX64 => .iosX64,
  .linuxArm => .linuxArm,
  .linuxArm64 => .linuxArm64,
  .linuxIA32 => .linuxIA32,
  .linuxX64 => .linuxX64,
  .linuxRiscv32 => .linuxRiscv32,
  .linuxRiscv64 => .linuxRiscv64,
  .macosArm64 => .macosArm64,
  // .macosArm64e => .macosArm64e,
  .macosX64 => .macosX64,
  .windowsArm64 => .windowsArm64,
  .windowsIA32 => .windowsIA32,
  .windowsX64 => .windowsX64,
  _ => throw UnsupportedError('No xffi platform target found for this platform'),
};