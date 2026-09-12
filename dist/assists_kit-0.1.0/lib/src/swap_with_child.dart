/// "Swap with child" / "Swap with parent": exchange a wrapper with the single
/// widget it wraps, keeping every other argument on its own widget.
library;

import 'package:analysis_server_plugin/edit/correction_utils.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';

class SwapWithChild extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.swap.withChild',
    30,
    'Swap with child',
  );

  SwapWithChild({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final parent = findWidgetCreation(node);
    if (parent == null) return;
    final childExpr = singleWrappedWidget(parent);
    if (childExpr is! InstanceCreationExpression) return;
    await _swap(builder, parent, childExpr);
  }

  Future<void> _swap(
    ChangeBuilder builder,
    InstanceCreationExpression parent,
    InstanceCreationExpression child,
  ) async {
    final text = swappedText(parent, child, utils);
    if (text == null) return;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(parent), text);
    });
  }
}

class SwapWithParent extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.swap.withParent',
    30,
    'Swap with parent',
  );

  SwapWithParent({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final child = findWidgetCreation(node);
    if (child == null) return;
    // The parent is the creation whose single wrapped widget is [child].
    AstNode? up = child.parent;
    while (up != null && up is! InstanceCreationExpression) {
      if (up is FunctionBody || up is Statement) return;
      up = up.parent;
    }
    final parent = up as InstanceCreationExpression?;
    if (parent == null || !isWidgetType(parent.staticType)) return;
    if (singleWrappedWidget(parent) != child) return;
    final text = swappedText(parent, child, utils);
    if (text == null) return;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(parent), text);
    });
  }
}

/// Text for [child] wrapping [parent] with their roles exchanged:
/// `A(x: 1, child: B(y: 2, child: C()))` becomes
/// `B(y: 2, child: A(x: 1, child: C()))`.
///
/// Only single-`child:` pairs are swapped; a `children:` list on either side
/// returns null.
String? swappedText(
  InstanceCreationExpression parent,
  InstanceCreationExpression child,
  CorrectionUtils utils,
) {
  final parentChild = childArgument(parent);
  final childChild = childArgument(child);
  if (parentChild == null || childChild == null) return null;

  String withoutChild(InstanceCreationExpression creation, NamedArgument c) {
    final args = creation.argumentList.arguments
        .where((a) => a != c)
        .map(utils.getNodeText)
        .toList();
    return args.join(', ');
  }

  final parentName = utils.getNodeText(parent.constructorName);
  final childName = utils.getNodeText(child.constructorName);
  final parentConst = parent.keyword?.lexeme ?? '';
  final childConst = child.keyword?.lexeme ?? '';
  final grandChild = utils.getNodeText(childChild.argumentExpression);
  final parentArgs = withoutChild(parent, parentChild);
  final childArgs = withoutChild(child, childChild);

  String call(String kw, String name, String args, String inner) {
    final prefix = kw.isEmpty ? '' : '$kw ';
    final sep = args.isEmpty ? '' : '$args, ';
    return '$prefix$name(${sep}child: $inner)';
  }

  final innerCall = call(parentConst, parentName, parentArgs, grandChild);
  return call(childConst, childName, childArgs, innerCall);
}
