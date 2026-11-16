// ignore_for_file: implementation_imports

import 'package:ffigen/src/context.dart';
import 'package:ffigen/src/visitor/ast.dart';

// This file exists purely because public api of ffigen is dumb and there is
// collision between:
//   - ffigen-22.0.0/lib/src/visitor/visitor.dart
//   - ffigen-22.0.0/lib/src/config_provider/public_visitor.dart

void doVisit(Context context, Visitation visitor, Iterable<AstNode> nodes, {bool debug = false})
  => Visitor(context, visitor, debug: debug).visitAll(nodes);
