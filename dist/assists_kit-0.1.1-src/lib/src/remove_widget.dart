/// "Remove this widget": replace a wrapper with the single widget it wraps.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';

class RemoveWidget extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.removeWidget',
    30,
    'Remove this widget',
  );

  RemoveWidget({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final creation = findWidgetCreation(node);
    if (creation == null) return;
    final wrapped = singleWrappedWidget(creation);
    if (wrapped == null) return;
    final text = utils.getNodeText(wrapped);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(creation), text);
    });
  }
}
