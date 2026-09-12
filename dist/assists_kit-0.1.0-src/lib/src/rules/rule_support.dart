/// Shared pieces for the DartNative warning rules.
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../dartnative_widgets.dart';

/// A [LintCode] reported at warning severity. Rules registered with
/// `registerWarningRule` are enabled by default, so every code here is a
/// genuine "this will not do what you expect" case, never a style opinion.
LintCode warning(String name, String problem, {required String correction}) =>
    LintCode(
      name,
      problem,
      correctionMessage: correction,
      severity: DiagnosticSeverity.WARNING,
    );

/// A visitor that only looks at creations of one DartNative class.
///
/// Subclasses implement [check] and are handed every `InstanceCreationExpression`
/// whose static type is exactly the DartNative class named [className].
abstract class CreationVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;
  final String className;

  CreationVisitor(this.rule, this.context, {required this.className});

  void check(InstanceCreationExpression node);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (isDartNativeCreation(node, className)) check(node);
  }
}
