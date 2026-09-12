/// "Move widget up" / "Move widget down" inside a `children:` list.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';

class MoveWidgetUp extends _MoveWidget {
  static const _kind = AssistKind(
    'dartnative.assist.move.up',
    30,
    'Move widget up',
  );

  MoveWidgetUp({required super.context}) : super(delta: -1);

  @override
  AssistKind get assistKind => _kind;
}

class MoveWidgetDown extends _MoveWidget {
  static const _kind = AssistKind(
    'dartnative.assist.move.down',
    30,
    'Move widget down',
  );

  MoveWidgetDown({required super.context}) : super(delta: 1);

  @override
  AssistKind get assistKind => _kind;
}

/// Swaps the selected widget with its neighbour [delta] positions away in
/// the enclosing `children:` list literal.
abstract class _MoveWidget extends ResolvedCorrectionProducer {
  final int delta;

  _MoveWidget({required super.context, required this.delta});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final creation = findWidgetCreation(node);
    if (creation == null) return;
    final list = creation.parent;
    if (list is! ListLiteral) return;
    final elements = list.elements;
    final index = elements.indexOf(creation);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= elements.length) return;
    final neighbour = elements[target];
    if (neighbour is! Expression) return;

    final creationText = utils.getNodeText(creation);
    final neighbourText = utils.getNodeText(neighbour);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(creation), neighbourText);
      builder.addSimpleReplacement(range.node(neighbour), creationText);
    });
  }
}
