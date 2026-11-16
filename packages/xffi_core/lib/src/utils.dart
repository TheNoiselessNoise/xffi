part of '../xffi_core.dart';

/// Dart-side utility helpers.
final class XUtils {
  XUtils._();

  // Injectable

  static int _vsnprintf(XPtr<XUint8> str, int size, XPtr<XChar> format, XPtr<XVoid> ap)
    => throw StateError('XUtils.vsnprintf not initialized by backend');

  static int Function(XPtr<XUint8> str, int size, XPtr<XChar> format, XPtr<XVoid> ap) vsnprintf = _vsnprintf;

  // Other

  /// Combines multiple [XEnum] values into a single bitmask via bitwise OR.
  static int EnumsAsFlagsOr(Iterable<XEnum> values)
    => values.fold(0, (acc, e) => acc | e.value);

  // Format

  static final _fmtSpecifier = RegExp(r'%(?!%)([-+ #0]*)(\d+|\*)?(?:\.(\d+|\*))?[hlLqjzt]*([diouxXeEfFgGaAcspn])');

  /// Checks if [s] contains any `printf format specifiers`.
  static bool HasFormatSpecifier(String s) => _fmtSpecifier.hasMatch(s);

  /// Formats [fmt] printf-style, consuming positional arguments from [args].
  ///
  /// Supports the standard conversions (`d i u o x X e E f F g G a A c s p`),
  /// flags (`- + space # 0`), width/precision (including `*`), and ignores
  /// length modifiers (`h l L q j z t`) since Dart ints/doubles are already
  /// fixed-width.
  ///
  /// Any literal `%` left over from substituted values is escaped to
  /// `%%` so native `printf` can't reinterpret it.
  ///
  /// Known caveats:
  /// - `%g`/`%G` use [double.toStringAsPrecision], which doesn't exactly
  ///   match C's "shortest of %e/%f, trim trailing zeros" rule, close
  ///   enough for logging, not bit-exact.
  /// - `%u` always prints via `toUnsigned(64)`. If a value is a genuinely
  ///   32-bit unsigned quantity represented as a negative 32-bit signed int,
  ///   this will print the wrong magnitude, length modifiers are currently
  ///   ignored, so there's no way to request `toUnsigned(32)` instead.
  /// - `NaN`/`Infinity` are not special-cased: `toStringAsFixed` and
  ///   `toStringAsExponential` throw on non-finite doubles, so passing one
  ///   to `%e/%f/%g` will throw rather than print `nan`/`inf`.
  static String Format(String fmt, [List<Object?> args = const []]) {
    var argIdx = 0;
    Object? nextArg() {
      if (argIdx >= args.length) {
        throw StateError('`$fmt` expects more args than the ${args.length} provided.');
      }
      return args[argIdx++];
    }

    final out = StringBuffer();
    var last = 0;
    for (final m in _fmtSpecifier.allMatches(fmt)) {
      out.write(fmt.substring(last, m.start));
      last = m.end;
      final flags = m.group(1) ?? '';
      final width = _resolveIntField(m.group(2), nextArg);
      final precision = m.group(3) == null ? null : _resolveIntField(m.group(3), nextArg);
      out.write(_formatOne(m.group(4)!, flags, width, precision, nextArg));
    }
    out.write(fmt.substring(last));

    if (argIdx != args.length) {
      throw StateError('`$fmt` consumed $argIdx args but ${args.length} were provided.');
    }

    // Escape any literal `%` that came from substituted values so
    // native `printf` doesn't reinterpret it.
    return out.toString().replaceAll('%', '%%');
  }

  static int? _resolveIntField(String? raw, Object? Function() nextArg) {
    if (raw == null) return null;
    if (raw == '*') {
      final v = nextArg();
      if (v is! int) throw StateError('`*` field expects an int, got $v.');
      return v;
    }
    return int.parse(raw);
  }

  static String _formatOne(String conv, String flags, int? width, int? precision, Object? Function() nextArg) {
    final leftAlign = flags.contains('-');
    final zeroPad = flags.contains('0') && !leftAlign;
    final plus = flags.contains('+');
    final space = flags.contains(' ');
    final alt = flags.contains('#');

    String body;
    switch (conv) {
      case 'd':
      case 'i':
        final v = _asInt(nextArg());
        body = v.abs().toString();
        if (precision != null) body = body.padLeft(precision, '0');
        body = v < 0 ? '-$body' : (plus ? '+$body' : (space ? ' $body' : body));
      case 'u':
        body = _asInt(nextArg()).toUnsigned(64).toString();
      case 'o':
        body = _asInt(nextArg()).toRadixString(8);
        if (alt && !body.startsWith('0')) body = '0$body';
      case 'x':
        body = _asInt(nextArg()).toRadixString(16);
        if (alt) body = '0x$body';
      case 'X':
        body = _asInt(nextArg()).toRadixString(16).toUpperCase();
        if (alt) body = '0X$body';
      case 'c':
        final v = nextArg();
        body = v is int ? String.fromCharCode(v) : v.toString();
      case 's':
        final v = nextArg();
        if (v is XPtr) {
          body = v.cast<XChar>().toDartString();
        } else {
          body = v.toString();
        }
        if (precision != null && precision < body.length) body = body.substring(0, precision);
      case 'e' || 'E' || 'f' || 'F' || 'g' || 'G' || 'a' || 'A':
        body = _formatFloat(_asDouble(nextArg()), conv, precision, plus, space);
      case 'p':
        body = '0x${_asInt(nextArg()).toRadixString(16)}';
      default:
        throw StateError('Unsupported format specifier `%$conv`.');
    }

    if (width != null && body.length < width) {
      body = leftAlign
        ? body.padRight(width)
        : (zeroPad && conv != 's' && conv != 'c' ? _zeroPadSigned(body, width) : body.padLeft(width));
    }
    return body;
  }

  static String _zeroPadSigned(String s, int width) {
    final signed = s.startsWith('-') || s.startsWith('+');
    final sign = signed ? s[0] : '';
    final digits = signed ? s.substring(1) : s;
    return '$sign${digits.padLeft(width - sign.length, '0')}';
  }

  static int _asInt(Object? v) => switch (v) {
    XPtr p => p.address,
    int i => i,
    double d => d.toInt(),
    _ => throw StateError('Expected int arg, got $v.'),
  };

  static double _asDouble(Object? v) => switch (v) {
    double d => d,
    int i => i.toDouble(),
    _ => throw StateError('Expected numeric arg, got $v.'),
  };

  static String _formatFloat(double v, String conv, int? precision, bool plus, bool space) {
    final p = precision ?? 6;
    var body = switch (conv) {
      'e' || 'E' => v.toStringAsExponential(p),
      'g' || 'G' => v.toStringAsPrecision(p == 0 ? 1 : p),
      _ => v.toStringAsFixed(p),
    };
    if (conv == 'E' || conv == 'G') body = body.toUpperCase();
    if (v >= 0) body = plus ? '+$body' : (space ? ' $body' : body);
    return body;
  }

  /// Splits on `_`, `-`, ` ` and camel/Pascal-case boundaries.
  static List<String> TextSplitWords(String text) {
    final result = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '_' || c == '-' || c == ' ') {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
      } else if (buffer.isNotEmpty && c != c.toLowerCase() && c == c.toUpperCase()) {
        result.add(buffer.toString());
        buffer.clear();
        buffer.write(c);
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());
    return result;
  }

  /// Allocates a new memory block of [newSize] bytes, copies the contents of
  /// [oldPtr] up to the smaller of [oldSize] and [newSize], and frees [oldPtr].
  ///
  /// Returns a pointer to the newly allocated memory block.
  static XPtr<XVoid> realloc(XPtr oldPtr, int oldSize, int newSize) {
    final XPtr<XVoid> newPtr = .malloc(newSize);
    newPtr.copyBytesFrom(oldPtr, oldSize < newSize ? oldSize : newSize);
    oldPtr.free();
    return newPtr;
  }

  /// Fills [size] bytes at [ptr] with [value].
  static void memset(XPtr ptr, int value, int size)
    => ptr.fillBytes(value, size);

  /// Copies [n] bytes from [src] to [dest].
  static void memcpy(XPtr dest, XPtr src, int n)
    => dest.copyBytesFrom(src, n);

  /// Compares the first [n] bytes of [a] and [b].
  ///
  /// Returns zero if they are equal, a negative value if [a] is less than [b],
  /// or a positive value if [a] is greater than [b].
  static int memcmp(XPtr a, XPtr b, int n)
    => a.compareBytes(b, n);

  /// Returns the length of the null-terminated string at [ptr],
  /// excluding the terminating null byte.
  static int strlen(XPtr ptr) {
    var i = 0;
    while (ptr.readUint8(i) != 0) i++;
    return i;
  }

  /// Returns the length of the string at [ptr], up to [maxLen] bytes.
  ///
  /// Stops at the first null byte or when [maxLen] bytes have been examined.
  /// The terminating null byte is not included in the returned length.
  static int strnlen(XPtr ptr, int maxLen) {
    var i = 0;
    while (i < maxLen && ptr.readUint8(i) != 0) i++;
    return i;
  }

  /// Compares two null-terminated strings at [a] and [b].
  ///
  /// Returns zero if they are equal, a negative value if [a] is less than [b],
  /// or a positive value if [a] is greater than [b].
  static int strcmp(XPtr a, XPtr b) {
    var i = 0;
    while (true) {
      final ca = a.readUint8(i), cb = b.readUint8(i);
      if (ca != cb) return ca - cb;
      if (ca == 0) return 0;
      i++;
    }
  }

  /// Copies the null-terminated string at [src] into [dest],
  /// including its terminating null byte.
  ///
  /// The destination must have sufficient capacity.
  static void strcpy(XPtr dest, XPtr src)
    => dest.copyBytesFrom(src, strlen(src) + 1); // include NUL

  /// Copies up to [n] bytes from the null-terminated string at [src] into [dest].
  ///
  /// If the source is shorter than [n] bytes, the remaining destination bytes
  /// are padded with null bytes. Otherwise, the destination is not
  /// null-terminated.
  ///
  /// The destination must have capacity for at least [n] bytes.
  static void strncpy(XPtr dest, XPtr src, int n) {
    final srcLen = strlen(src);
    final copyLen = srcLen < n ? srcLen + 1 : n; // include NUL only if it fits
    dest.copyBytesFrom(src, copyLen);
    if (copyLen < n) dest.fillBytes(0, n - copyLen, copyLen); // pad rest with NUL
  }

  /// Appends up to [n] bytes from the null-terminated string at [src]
  /// to the null-terminated string at [dest].
  ///
  /// Writes a terminating null byte after the appended contents.
  /// The destination must have sufficient capacity for the resulting string.
  static void strncat(XPtr dest, XPtr src, int n) {
    final destLen = strlen(dest);
    final copyLen = strlen(src).clamp(0, n);
    dest.copyBytesFrom(src, copyLen, destOffset: destLen);
    dest.offsetBy(destLen + copyLen).fillBytes(0, 1); // terminator
  }

  /// Searches for the first occurrence of the null-terminated string at [needle]
  /// within the null-terminated string at [haystack].
  ///
  /// Returns a pointer to the beginning of the first match, or a null pointer
  /// if no match is found. An empty [needle] matches at the beginning of
  /// [haystack].
  static XPtr<XVoid> strstr(XPtr haystack, XPtr needle) {
    final needleLen = strlen(needle);
    if (needleLen == 0) return haystack.cast();
    var i = 0;
    while (haystack.readUint8(i) != 0) {
      var j = 0;
      while (j < needleLen && haystack.readUint8(i + j) == needle.readUint8(j)) j++;
      if (j == needleLen) return haystack.offsetBy(i);
      i++;
    }
    return .nullptr();
  }

  /// Reverses the byte order of an 8-bit value.
  ///
  /// A single byte has no alternative byte order, so this is a no-op.
  static int swap8(int v) => v; // no-op, kept for symmetry

  /// Reverses the byte order of a 16-bit value.
  static int swap16(int v) =>
    ((v & 0xFF) << 8) |
    ((v >> 8) & 0xFF);

  /// Reverses the byte order of a 32-bit value.
  static int swap32(int v) =>
    ((v & 0xFF) << 24) |
    ((v & 0xFF00) << 8) |
    ((v >> 8) & 0xFF00) |
    ((v >> 24) & 0xFF);

  /// Reverses the byte order of a 64-bit value.
  static int swap64(int v) =>
    ((v & 0xFF) << 56) |
    ((v & 0xFF00) << 40) |
    ((v & 0xFF0000) << 24) |
    ((v & 0xFF000000) << 8) |
    ((v >> 8) & 0xFF000000) |
    ((v >> 24) & 0xFF0000) |
    ((v >> 40) & 0xFF00) |
    ((v >> 56) & 0xFF);
}