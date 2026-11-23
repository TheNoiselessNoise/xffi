import 'dart:math' as math;
import 'package:xffi_gen/xffi_gen.dart';
import 'package:ffigen/src/code_generator.dart';

final class TypedMember {
  final Struct struct;
  final CompoundMember field;
  final ParsedType type;

  const TypedMember(this.struct, this.field, this.type);

  String get path => '${struct.name}.$name';
  String get name => field.name;
  String get asDart => '_$name';
  String get asStruct => 'field_$name';

  void dump() {
    final title = '==== $path ====';
    print(title);

    print('');
    print('native: ${type.baseNativeType}');
    print('ffi: ${type.baseFfiType}');
    print('flat: ${type.baseFlatType}');
    print('dart: ${type.baseDartType}');
    print('');
    print('isStruct: ${type.isStruct}');
    print('isEnum: ${type.isEnum}');
    print('isPointer: ${type.isPointer}');
    print('isPointerPointer: ${type.isPointerPointer}');
    print('');

    print('=' * title.length);
  }
}

extension on Struct {
  Iterable<TypedMember> getTypedMembers(XContext context)
    => members.map((member) => .new(this, member, context.parseType(member)));
}

final class StructWriter extends Writable {
  final XContext context;
  final XStructMode mode;
  final Struct struct;

  StructWriter(this.context, this.mode, this.struct);

  String get name => struct.name;
  String get fieldsEnum => '${name}Field';

  Iterable<TypedMember>? _typedMembers;
  Iterable<TypedMember> get typedMembers => _typedMembers ??= struct.getTypedMembers(context);

  String get factoryMode => switch (mode) {
    .skip => throw StateError("unreachable"),
    .struct => 'create',
    .value => 'createValue',
  };

  void writeFieldEnum() {
    writeln('enum $fieldsEnum with StructFields {');
    for (final member in typedMembers) {
      padln('${member.name},');
    }
    writeln('}');
  }

  void writeStructDef() {
    padln('/// Describes the raw memory layout, construction, and pointer representation');
    padln('/// of this struct type.');
    padln('static final XStructDef<$name> struct = .$factoryMode(');
      pad2ln('factory: $name.new,');
      pad2ln('layout: .aligned<$fieldsEnum>({');

        String keyOf(TypedMember member) => '.${member.name}:';
        final width = typedMembers.fold<int>(0, (w, m) => math.max(w, keyOf(m).length));

        for (final member in typedMembers) {
          String length = '0';
          final override = context.config.overrideFor(struct.name, member.name);
          if (override case XFixedLength field) length = field.length.toString();
          if (override case XString field) length = field.length ?? member.type.arrayLength.toString();
          if (override case XLengthField field) {
            if (field.isExternal) {
              length = field.fieldName;
            } else {
              // throw StateError('Invalid non-external length for a field ${member.path}');
            }
          }
          pad3ln('${keyOf(member).padRight(width)} ${member.type.flatTypeInstance(length)},');
        }

      pad2ln('}),');
    padln(');');
  }

  void writeStructLayoutAndFields() {
    padln('/// Raw memory layout of this object.');
    padln('static final StructLayout<$fieldsEnum> _l = struct.layoutOf();');
    writeln();

    String declOf(TypedMember member) => 'static final ${member.asStruct} = ';
    final width = typedMembers.fold<int>(0, (w, m) => math.max(w, declOf(m).length));
    
    for (final member in typedMembers) {
      padln('/// Field descriptor for [${member.name}].');

      final name = member.name;
      final scalarDartType = member.type.scalarDartType;
      final flatType = member.type.baseFlatType;
      final rootType = member.type.rootType;
      final innerType = member.type.innerType;
      final override = context.config.overrideFor(struct.name, member.name);

      pad(declOf(member).padRight(width));

      write('_l.');

      if (member.type.isStruct) {
        writeln('struct<$scalarDartType>(.$name);');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Invalid ptrptr for field ${member.path}");
      } else if (member.type.isPointer) {
        if (innerType?.isArray ?? false) {
          if (rootType.isStruct) {
            writeln('pointerStructFixedArray<$scalarDartType>(.$name);');
          } else {
            writeln('pointerScalarFixedArray<$scalarDartType, $flatType>(.$name);');
          }
        } else {
          if (rootType.isStruct) {
            writeln('pointerStructArray<$scalarDartType>(.$name);');
          } else {
            writeln('pointerScalarArray<$scalarDartType, $flatType>(.$name);');
          }
        }
      } else if (member.type.isArray) {
        if (rootType.isStruct) {
          writeln('structArray<$scalarDartType>(.$name);');
        } else {
          if (override is XString) {
            writeln('stringAsCharArray<$flatType>(.$name);');
          } else {
            writeln('scalarArray<$scalarDartType, $flatType>(.$name);');
          }
        }
      } else {
        writeln('scalar<$scalarDartType, $flatType>(.$name);');
      }
    }
  }

  void writeDefFields() {
    for (final (i, member) in typedMembers.indexed) {
      final name = member.name;
      final rootType = member.type.rootType;
      final scalarDartType = member.type.scalarDartType;
      String dartType = member.type.baseDartType;
      final flatType = member.type.baseFlatType;
      final dartField = member.asDart;
      final structField = member.asStruct;
      final override = context.config.overrideFor(struct.name, member.name);

      if (member.type.isStruct) {
        padln('$dartType $dartField;');
        padln('$dartType get $name => $dartField = $structField.readOr(op, $dartField);');
        padln('set $name($dartType value) => $dartField = $structField.writeOr(op, value);');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Invalid ptrptr for field ${struct.name}.$name");
      } else if ((member.type.isPointer || member.type.isArray) && override is! XString) {
        String liveList = 'StructLiveList<$scalarDartType, $flatType>';
        if (rootType.isStruct) liveList = 'StructLiveListStruct<$scalarDartType>';
        padln('late final $liveList $dartField;');
        padln('$liveList get $name => $dartField;');
        padln('set $name($dartType value) => $dartField.inner = value;');
      } else {
        if (override is XString) dartType = 'String';
        padln('$dartType $dartField;');
        padln('$dartType get $name => $dartField = $structField.readOr(op, $dartField);');
        padln('set $name($dartType value) => $dartField = $structField.writeOr(op, value);');
      }

      if (i < typedMembers.length - 1) writeln();
    }
  }

  void writeDefConstructor() {
    final membersInInitializer = typedMembers.where(
      (m) => m.type.isStruct,
    );

    final membersInBody = typedMembers.where(
      (m) {
        final override = context.config.overrideFor(struct.name, m.name);
        final isArray = m.type.isArray && override is! XString;
        return isArray || m.type.isPointer || m.type.isPointerPointer;
      }
    );

    padln('$name({');
    pad2ln('super.op,');
    for (final member in typedMembers) {
      final override = context.config.overrideFor(struct.name, member.name);

      if (member.type.isStruct) {
        pad2ln('${member.type.baseDartType}? ${member.name},');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Double pointer... what to do?");
      } else if ((member.type.isPointer || member.type.isArray) && override is! XString) {
        pad2ln('${member.type.baseDartType}? ${member.name},');
      } else {
        if (override is XString) {
          pad2ln('this.${member.asDart} = \'\',');
        } else {
          pad2ln('this.${member.asDart} = 0,');
        }
      }
    }
    pad('})');
    if (membersInInitializer.isNotEmpty) {
      writeln(' : ');
      for (final (i, member) in membersInInitializer.indexed) {
        if (member.type.isStruct) {
          pad2('${member.asDart} = ${member.name} ?? .new()');
        } else {
          throw UnsupportedError("Unknown member in initializer list: ${member.path}");
        }

        writeln(i < membersInInitializer.length - 1 ? ',' : '');
      }
    }
    if (membersInBody.isEmpty) {
      writeln(';');
    } else {
      writeln(' {');
      for (final member in membersInBody) {
        final rootType = member.type.rootType;
        final override = context.config.overrideFor(struct.name, member.name);

        if (member.type.isPointerPointer) {
          throw UnsupportedError("Double pointer... what to do?");
        } else if (member.type.isPointer) {
          if (override case XLengthField length) {
            if (rootType.isStruct) {
              pad2ln('${member.asDart} = ${member.asStruct}.live(() => op, .generate(${length.fieldName}, (_) => .zero()));');
            } else {
              pad2ln('${member.asDart} = ${member.asStruct}.live(() => op, .filled(${length.fieldName}, 0));');
            }
          } else if (override != null) {
            throw Exception('membersInBody: ptr: Unhandled override ${override.runtimeType} for ${member.path}');
          } else {
            pad2ln('${member.asDart} = ${member.asStruct}.live(() => op, ${member.name});');
          }
        } else if (member.type.isArray) {
          if (rootType.isStruct) {
            pad2ln('${member.asDart} = ${member.asStruct}.live(() => op, ${member.name} ?? .generate(${member.asStruct}.codec.type.count, (_) => .zero()));');
          } else {
            pad2ln('${member.asDart} = ${member.asStruct}.live(() => op, ${member.name} ?? .filled(${member.asStruct}.codec.type.count, 0));');
          }
        }
      }
      padln('}');
    }
    writeln();
    padln('factory $name.zero() => .new();');
  }

  void writeDefInternals() {
    final membersInAllocation = typedMembers.where(
      (m) => m.type.isPointer || m.type.isPointerPointer
    );

    // setDart
    padln('@override');
    padln('$name setDart($name o) {');
    for (final member in typedMembers) {
      if (member.type.isStruct) {
        pad2ln('${member.name}.setDart(o.${member.name});');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Double pointer... what to do?");
      } else if (member.type.isPointer) {
        pad2ln('${member.name} = .from(o.${member.name});');
      } else {
        pad2ln('${member.name} = o.${member.name};');
      }
    }
    pad2ln('return this;');
    padln2('}');

    if (membersInAllocation.isNotEmpty) {
      padln('@override');
      padln('void structAllocateInto(MemoryTemp temp, XPtr p, String key) {');
      for (final member in membersInAllocation) {
        if (member.type.isPointerPointer) {
          throw UnsupportedError("Double pointer... what to do?");
        } else if (member.type.isPointer) {
          pad2ln("${member.asStruct}.allocate(temp, p, '\${key}_${member.name}', count: 0);");
        } else {
          throw UnsupportedError("Unknown member in allocation list: ${member.path}");
        }
      }
      padln2('}');
    }

    // structWriteInto
    padln('@override');
    padln('void structWriteInto(XPtr p) {');
    for (final member in typedMembers) {
      if (member.type.isStruct) {
        pad2ln('${member.asStruct}.write(p, ${member.asDart});');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Double pointer... what to do?");
      } else if (member.type.isPointer) {
        pad2ln('${member.asDart}.writeInto(p);');
      } else {
        pad2ln('${member.asStruct}.write(p, ${member.asDart});');
      }
    }
    padln2('}');

    // structReadFrom
    padln('@override');
    padln('void structReadFrom(XPtr p) {');
    for (final member in typedMembers) {
      final override = context.config.overrideFor(struct.name, member.name);

      if (member.type.isStruct) {
        pad2ln('${member.name} = ${member.asStruct}.read(p);');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Double pointer... what to do?");
      } else if (member.type.isPointer) {
        if (override case XLengthField length) {
          pad2ln('${member.name}.readFrom(p, count: ${length.fieldName});');
        } else if (override != null) {
          throw Exception('membersInBody: ptr: Unhandled override ${override.runtimeType} for ${member.path}');
        } else {
          pad2ln('${member.name}.readFrom(p);');
        }
      } else if (member.type.isArray) {
        if (override case XString fieldOverride) {
          final length = fieldOverride.length ?? member.type.arrayLength;
          pad2ln('${member.asStruct}.readBounded(p, $length);');
        } else {
          pad2ln('${member.name}.readFrom(p);');
        }
      } else {
        pad2ln('${member.name} = ${member.asStruct}.read(p);');
      }
    }
    padln2('}');

    // clone
    padln('@override');
    padln('$name clone() => .new(');
    pad2ln('op: op,');
    for (final member in typedMembers) {
      if (member.type.isStruct) {
        pad2ln('${member.name}: ${member.name}.clone(),');
      } else if (member.type.isPointerPointer) {
        throw UnsupportedError("Double pointer... what to do?");
      } else if (member.type.isPointer) {
        pad2ln('${member.name}: .from(${member.name}),');
      } else {
        pad2ln('${member.name}: ${member.name},');
      }
    }
    padln2(');');

    // signature
    padln('@override');
    padln("String signature() => '\$structName()';");
  }

  void writeClass() {
    writeln('class $name extends MemoryStruct<$name> {');
    writeln();
    writeStructDef();
    writeln();
    writeStructLayoutAndFields();
    writeln();
    writeDefFields();
    writeln();
    writeDefConstructor();
    writeln();
    writeDefInternals();
    writeln();
    writeln('}');
  }

  String writeDartStruct() => writeIsolated(() {
    print("writing struct '$name' with mode ${mode.name}...");

    writeFieldEnum();
    writeln();
    writeClass();
  });
}

final class MyC2DartWriter extends C2DartWriter {
  MyC2DartWriter(super.context);

  void _writeHeader() {
    writeln('// GENERATED FILE - do not edit by hand.');
    writeln('// ignore_for_file: non_constant_identifier_names');
    writeln();
    writeln("import 'package:raylib_dartified/raylib_dartified.dart';");
    writeln();
  }

  @override
  String writeContent() => writeIsolated(() {
    _writeHeader();

    final allowed = <String>[
      'Model', 'Matrix', 'Mesh',
      'Material', 'ModelSkeleton', 'Transform',
      'Shader', 'MaterialMap',
      'Texture', 'Color', 'BoneInfo',
      'Vector2', 'Vector3', 'Vector4'
    ];
    for (final MapEntry(key: name, value: struct) in visitor.structs.entries) {
      final mode = context.config.modeFor(name);
      if (mode == .skip) continue;
      if (!allowed.contains(name)) continue;

      writeSection(name);
      write(StructWriter(context, mode, struct).writeDartStruct());
    }
  });
}
