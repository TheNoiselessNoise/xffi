part of '../xffi_core.dart';

enum _VaListAbi {
  sysvX64,
  aarch64Lp64,
  slot8,
  wasm32,
}

mixin _Cursor {
  XPtr _p(int a) => .fromAddress(a);
  int int32();
  int int64();
  double f64();
  double longDouble();
  int ptr();

  double _binary128(XPtr a) {
    final lo = a.readInt64();
    final hi = (a + 8).readInt64();

    final negative = hi < 0;
    final exponent = (hi >>> 48) & 0x7FFF;
    final fractionHi = hi & 0x0000FFFFFFFFFFFF;
    final fractionLo = lo < 0
      ? lo.toDouble() + 18446744073709551616.0
      : lo.toDouble();

    double value;
    if (exponent == 0x7FFF) {
      value = (fractionHi == 0 && lo == 0) ? double.infinity : double.nan;
    } else {
      final fraction =
        fractionHi / 281474976710656.0 +
        fractionLo / 5192296858534827628530496329220096.0;
      value = exponent == 0
        ? fraction * math.pow(2, 1 - 16383)
        : (1 + fraction) * math.pow(2, exponent - 16383);
    }
    return negative ? -value : value;
  }
}

/// SysV x86-64: {u32 gp_offset, u32 fp_offset, void* overflow, void* reg_save}
final class _SysV with _Cursor {
  _SysV(XPtr va) :
    gp = (va).readUint32(),
    fp = (va + 4).readUint32(),
    ov = (va + 8).readInt64(),
    rs = (va + 16).readInt64();

  int gp, fp, ov, rs;

  XPtr _gp() {
    if (gp < 48) {
      final a = rs + gp;
      gp += 8;
      return _p(a);
    }
    return _ov(8);
  }

  XPtr _fp() {
    if (fp < 176) {
      final a = rs + fp;
      fp += 16;
      return _p(a);
    } // XMM slots are 16 apart
    return _ov(8);
  }

  XPtr _ov(int size, {int align = 8}) {
    ov = (ov + align - 1) & ~(align - 1);
    final a = ov;
    ov += size < 8 ? 8 : size;
    return _p(a);
  }

  @override int int32() => _gp().readInt32();
  @override int int64() => _gp().readInt64();
  @override int ptr() => _gp().readInt64();
  @override double f64() => _fp().readFloat64();

  /// x87 80-bit: class X87 is always passed in memory, 16-byte aligned, 16-byte slot.
  @override double longDouble() {
    final a = _ov(16, align: 16);
    final mant = a.readInt64();
    final se = (a + 8).readUint32() & 0xFFFF;
    final neg = (se & 0x8000) != 0;
    final e = se & 0x7FFF;
    final d = (mant >>> 32) * 4294967296.0 + (mant & 0xFFFFFFFF); // unsigned 64 -> double
    double r;
    if (e == 0x7FFF) {
      r = (mant << 1) == 0 ? double.infinity : double.nan; // integer bit masked off
    } else if (e == 0) {
      r = d * math.pow(2, -16382 - 63);
    } else {
      r = (d / 9223372036854775808.0) * math.pow(2, e - 16383);
    }
    return neg ? -r : r;
  }
}

/// Win64 / WinARM64 / Apple arm64: va_list IS the pointer, every arg occupies an
/// 8-byte slot, doubles included (the callee spills XMM/GPR to the slots).
final class _Slot8 with _Cursor {
  _Slot8(this.cur);
  XPtr cur;
  XPtr _n() {
    final a = cur;
    cur += 8;
    return a;
  }
  @override int int32() => _n().readInt32(); // little-endian: low half of the slot
  @override int int64() => _n().readInt64();
  @override int ptr() => _n().readInt64();
  @override double f64() => _n().readFloat64();
  @override double longDouble() => _n().readFloat64(); // MSVC: long double == double
}

/// wasm32: va_list is a void* into a buffer, each arg aligned to its own alignment.
final class _Wasm32 with _Cursor {
  _Wasm32(this.cur);
  XPtr cur;
  XPtr _n(int size) {
    cur = (cur + size - 1) & ~(size - 1);
    final a = cur;
    cur += size;
    return a;
  }
  @override int int32() => _n(4).readInt32();
  @override int int64() => _n(8).readInt64();
  @override int ptr() => _n(4).readInt32() & 0xFFFFFFFF;
  @override double f64() => _n(8).readFloat64();
  @override double longDouble() => _binary128(_n(16));
}

/// AArch64 AAPCS64: { void* stack; void* gr_top; void* vr_top; int gr_offs; int vr_offs; }
/// GPR: 8 registers, 8-byte slots.
/// SIMD/FP: 8 registers, 16-byte slots.
final class _AArch64 with _Cursor {
  _AArch64(XPtr va) :
    stack = va.readInt64(),
    grTop = (va + 8).readInt64(),
    vrTop = (va + 16).readInt64(),
    grOffs = (va + 24).readInt32(),
    vrOffs = (va + 28).readInt32();

  int stack, grTop, vrTop;
  int grOffs, vrOffs;

  XPtr _gp() {
    if (grOffs < 0) {
      final a = grTop + grOffs;
      grOffs += 8;
      return _p(a);
    }
    return _stack(8);
  }

  XPtr _fp() {
    if (vrOffs < 0) {
      final a = vrTop + vrOffs;
      vrOffs += 16;
      return _p(a);
    }
    return _stack(8);
  }

  XPtr _stack(int size, {int align = 8}) {
    stack = (stack + align - 1) & ~(align - 1);

    final a = stack;
    stack += (size + 7) & ~7;

    return _p(a);
  }

  @override
  int int32() => _gp().readInt32();

  @override
  int int64() => _gp().readInt64();

  @override
  int ptr() => _gp().readInt64();

  @override
  double f64() => _fp().readFloat64();

  @override double longDouble() => _binary128(vrOffs < 0 ? _fp() : _stack(16, align: 16));
}

final class XVaListInstance {
  XVaListInstance._(this.ptr, this._free);
  final XPtr<XVoid> ptr;
  final void Function() _free;
  void dispose() => _free();
}

enum _BuildElKind {
  i32,
  i64,
  f64,
  ptr,
}

final class VaListBuilder {
  VaListBuilder._(this._abi);
  final _VaListAbi _abi;

  final _args = <(_BuildElKind kind, Object v)>[];
  final _owned = <XPtr>[];

  VaListBuilder i32(int v) => this.._args.add((.i32, v));
  VaListBuilder i64(int v) => this.._args.add((.i64, v));
  VaListBuilder f64(double v) => this.._args.add((.f64, v));
  VaListBuilder ptr(int addr) => this.._args.add((.ptr, addr));
  VaListBuilder string(String s) {
    final a = XPtr.fromString(s);
    _owned.add(a);
    _args.add((.ptr, a));
    return this;
  }

  XVaListInstance build() {
    final isWasm = _abi == .wasm32;
    final head = switch (_abi) {
      .sysvX64     => 32 + 176, // header(24, padded) + reg_save_area
      .aarch64Lp64 => 32,       // header
      _            => 0,
    };
    final body = _args.length * 8 + 16;
    final base = XPtr.calloc<XVoid>(1, head + body);
    var cur = base + head;

    void slot(_BuildElKind kind, Object v) {
      switch (kind) {
        case .i32: {
          cur.writeInt64(v is XPtr ? v.address : v as int);
          cur += 8;
        }
        case .i64 || .ptr: {
          cur.writeInt64(v is XPtr ? v.address : v as int);
          cur += 8;
        }
        case .f64: {
          cur.writeFloat64(v as double);
          cur += 8;
        }
      }
    }

    void packed(_BuildElKind kind, Object v) {
      void align(int a) => cur = (cur + a - 1) & ~(a - 1);
      switch (kind) {
        case .i32 || .ptr: {
          align(4);
          cur.writeInt32(v is XPtr ? v.address : v as int);
          cur += 4;
        }
        case .i64: {
          align(8);
          cur.writeInt64(v is XPtr ? v.address : v as int);
          cur += 8;
        }
        case .f64: {
          align(8);
          cur.writeFloat64(v as double); 
          cur += 8;
        }
      }
    }

    for (final (k, v) in _args) {
      isWasm ? packed(k, v) : slot(k, v);
    }

    final XPtr<XVoid> va;
    switch (_abi) {
      case .sysvX64:
        (base).writeInt32(48);                           // gp_offset: GP regs "used up"
        (base + 4).writeInt32(176);                      // fp_offset: XMM regs "used up"
        (base + 8).writeInt64((base + head).address);    // overflow_arg_area
        (base + 16).writeInt64((base + 24 + 8).address); // reg_save_area (dummy but valid)
        va = base;                                       // va_list param == pointer to this struct
      case .aarch64Lp64:
        (base).writeInt64((base + head).address); // __stack
        (base + 8).writeInt64(base.address);      // __gr_top (unused)
        (base + 16).writeInt64(base.address);     // __vr_top (unused)
        (base + 24).writeInt32(0);                // __gr_offs >= 0 -> stack
        (base + 28).writeInt32(0);                // __vr_offs >= 0 -> stack
        va = base;
      case .slot8 || .wasm32:
        va = base; // pointer to the buffer
    }

    final owned = List<XPtr>.of(_owned);
    return ._(va, () {
      owned.forEach((p) => p.free());
      base.free();
    });
  }
}

/// Totally hacked `va_list`
final class XVaList {
  XVaList._();

  // if `null`, by-value pointer
  static final int? _vaListStructSize = switch (currentMemoryPlatformTarget) {
    // SysV x86-64: 24-byte struct, passed as pointer
    .linuxX64 || .androidX64 || .fuchsiaX64 || .macosX64 || .iosX64 => 24,

    // AAPCS64 (non-Apple): 32-byte struct, passed as pointer to caller's copy
    .linuxArm64 || .androidArm64 || .fuchsiaArm64 => 32,

    // va_list is a plain pointer (or 1-pointer struct passed by value): pass through
    // .iosArm64e || .macosArm64e ||
    .macosArm64 || .iosArm64 || .iosArm ||
    .windowsX64 || .windowsArm64 || .windowsIA32 ||
    .linuxIA32 || .linuxArm || .linuxRiscv32 || .linuxRiscv64 ||
    .androidIA32 || .androidArm || .androidRiscv64 ||
    .fuchsiaRiscv64 || .web => null,

    .unknown => throw StateError('va_list layout unknown'),
  };

  static String format(XPtr<XChar> fmt, XPtr<XVoid> va) {
    final size = _vaListStructSize;
    final scratch = size == null ? null : XPtr.calloc<XUint8>(1, size);
    XPtr<XVoid> fresh() {
      if (scratch == null) return va;
      scratch.copyBytesFrom(va.cast(), size!);
      return scratch.cast();
    }

    try {
      final len = XPrint.vsnprintf(XPtr.nullptr(), 0, fmt, fresh());
      if (len < 0) return fmt.toDartString();

      final buf = XPtr.calloc<XUint8>(1, len + 1);
      try {
        XPrint.vsnprintf(buf, len + 1, fmt, fresh());
        return buf.cast<XChar>().toDartString(len);
      } finally {
        buf.free();
      }
    } finally {
      scratch?.free();
    }
  }

  // Extract va_list

  static final _VaListAbi _vaAbi = switch (currentMemoryPlatformTarget) {
    // System V AMD64
    .androidX64 || .fuchsiaX64 || .iosX64 || .linuxX64 || .macosX64 => .sysvX64,

    // Generic AAPCS64
    .androidArm64 || .fuchsiaArm64 || .linuxArm64 => .aarch64Lp64,

    // Microsoft / Apple pointer-based ABIs
    // .iosArm64e || .macosArm64e ||
    .windowsX64 || .windowsArm64 || .macosArm64 || .iosArm64 => .slot8,

    // WASM
    .web => .wasm32,

    // Not implemented yet
    _ => throw StateError('va_list ABI unknown for $currentMemoryPlatformTarget'),
  };

  static VaListBuilder get create => ._(_vaAbi);

  static List<Object?> extract(XPtr<XChar> fmt, XPtr<XVoid> va) {
    final cursor = switch (_vaAbi) {
      .sysvX64 => _SysV(va),
      .aarch64Lp64 => _AArch64(va),
      .slot8 => _Slot8(va),
      .wasm32 => _Wasm32(va),
    };
    return _extractVaList(fmt.toDartString(), cursor);
  }

  static List<Object?> _extractVaList(String fmt, _Cursor c) {
    final out = <Object?>[];
    bool dig(String s) => s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;
    var i = 0;
    while (i < fmt.length) {
      if (fmt[i++] != '%') continue;
      if (i < fmt.length && fmt[i] == '%') { i++; continue; }

      while (i < fmt.length && '-+ #0'.contains(fmt[i])) i++;                  // flags
      if (i < fmt.length && fmt[i] == '*') { out.add(c.int32()); i++; }        // width
      else { while (i < fmt.length && dig(fmt[i])) i++; }
      if (i < fmt.length && fmt[i] == '.') {                                   // precision
        i++;
        if (i < fmt.length && fmt[i] == '*') { out.add(c.int32()); i++; }
        else { while (i < fmt.length && dig(fmt[i])) i++; }
      }

      var size = 4;
      var ld = false;
      if (fmt.startsWith('I64', i)) { size = 8; i += 3; }                      // MS
      else if (fmt.startsWith('I32', i)) { size = 4; i += 3; }                 // MS
      else if (i < fmt.length && fmt[i] == 'I') { size = XPtrType.size; i++; }         // MS
      else if (fmt.startsWith('ll', i)) { size = 8; i += 2; }
      else if (fmt.startsWith('hh', i)) { i += 2; }
      else if (i < fmt.length && 'hlLqjzt'.contains(fmt[i])) {
        switch (fmt[i]) {
          case 'l': size = XLong.size;
          case 'q' || 'j': size = 8;
          case 'z' || 't': size = XPtrType.size;
          case 'L': ld = true;
        }
        i++;
      }
      if (i >= fmt.length) break;

      final conv = fmt[i++];
      switch (conv) {
        case 'd' || 'i':
          out.add(size == 8 ? c.int64() : c.int32());
        case 'u' || 'x' || 'X' || 'o':
          out.add(size == 8 ? c.int64() : c.int32() & 0xFFFFFFFF); // u64 wraps in Dart
        case 'c':
          out.add(c.int32());
        case 'e' || 'E' || 'f' || 'F' || 'g' || 'G' || 'a' || 'A':
          out.add(ld ? c.longDouble() : c.f64());
        case 's':
          final p = XPtr.fromAddress<XChar>(c.ptr());
          out.add(p.isNull ? null : p.toDartString());
        case 'p':
          out.add(c.ptr()); // raw address
        case 'n':
          c.ptr();          // consumes a slot, writes nothing
        default:
          throw UnsupportedError('%$conv in "$fmt"');
      }
    }
    return out;
  }
}