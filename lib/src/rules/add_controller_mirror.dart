/// Quick fix for `dartnative_mirror_text_controller`: adds the `onChanged`
/// mirror next to the `controller:` argument.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddControllerMirror extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'dartnative.fix.addControllerMirror',
    DartFixKindPriority.standard,
    "Add 'onChanged' mirror for the controller",
  );

  AddControllerMirror({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final argument = node;
    if (argument is! NamedArgument) return;
    final controller = argument.argumentExpression;
    // Only mirror to a plain reference; a fresh `TextEditingController()`
    // inline would be mirrored into a throwaway instance.
    if (controller is! Identifier) return;
    final text = utils.getNodeText(controller);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        argument.end,
        ', onChanged: (value) => $text.text = value',
      );
    });
  }
}
