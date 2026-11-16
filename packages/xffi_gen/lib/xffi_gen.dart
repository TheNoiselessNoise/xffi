// ignore_for_file: implementation_imports

library;

import 'dart:io' show File, Process;

import 'package:logging/logging.dart';
import 'package:ffigen/src/logger.dart';
import 'package:ffigen/src/context.dart';
import 'package:ffigen/src/config_provider.dart';
import 'package:ffigen/src/header_parser/parser.dart';
import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/code_generator/utils.dart';
// for collecting stuff
import 'package:ffigen/src/visitor/ast.dart' show Visitation;
// public api - for allowing stuff
import 'package:ffigen/ffigen.dart' show Visitor;
import 'package:xffi_gen/src/visit.dart' show doVisit;

part 'src/base.dart';
part 'src/c2dart.dart';
part 'src/classify.dart';
part 'src/config.dart';
part 'src/model.dart';
part 'src/type_resolver.dart';