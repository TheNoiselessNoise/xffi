library;

import 'dart:math' as math;
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'src/native_target/native_target.dart';
import 'src/platform/platform.dart';
import 'src/consts/consts.dart';

export 'src/native_target/native_target.dart';
export 'src/platform_type/platform_type.dart';
export 'src/platform/platform.dart';

part 'src/allocator/base.dart';
part 'src/allocator/scalar.dart';
part 'src/allocator/string.dart';
part 'src/allocator/struct.dart';
part 'src/codecs.dart';
part 'src/config.dart';
part 'src/debug.dart';
part 'src/enum.dart';
part 'src/fields.dart';
part 'src/list.dart';
part 'src/memory_pointer.dart';
part 'src/memory_type.dart';
part 'src/module.dart';
part 'src/output.dart';
part 'src/platform.dart';
part 'src/scalar_types.dart';
part 'src/scratch.dart';
part 'src/struct_layout.dart';
part 'src/struct_types.dart';
part 'src/struct.dart';
part 'src/temp.dart';
part 'src/trace.dart';
part 'src/utils.dart';
part 'src/va_list.dart';