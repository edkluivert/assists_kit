/// "Convert to children:" and "Convert to child:".
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';

/// Turns `child: X` into `children: [X]` on the selected widget creation.
class ConvertChildToChildren extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.convert.childToChildren',
    30,
    'Convert to children:',
  );

  ConvertChildToChildren({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final creation = findWidgetCreation(node);
    if (creation == null) return;
    final child = childArgument(creation);
    if (child == null || childrenArgument(creation) != null) return;
    final value = utils.getNodeText(child.argumentExpression);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(child), 'children: [$value]');
    });
  }
}

/// Turns a one-element `children: [X]` into `child: X`.
class ConvertChildrenToChild extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.convert.childrenToChild',
    30,
    'Convert to child:',
  );

  ConvertChildrenToChild({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final creation = findWidgetCreation(node);
    if (creation == null) return;
    final children = childrenArgument(creation);
    final list = childrenList(creation);
    if (children == null || list == null || list.elements.length != 1) return;
    if (childArgument(creation) != null) return;
    final only = list.elements.single;
    if (only is! Expression) return;
    final value = utils.getNodeText(only);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(children), 'child: $value');
    });
  }
}
