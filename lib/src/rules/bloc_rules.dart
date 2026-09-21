/// Warning rules for flutterbloc_kit's BuildContext extensions.
///
/// `context.watch` / `context.select` subscribe the *building* element; called
/// anywhere else they read once and never rebuild. `context.read` never
/// subscribes; `context.read<T>().state` rendered in build is stale after the
/// first emit. Both fail silently, which is why they are warnings here.
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../dartnative_widgets.dart';
import 'rule_support.dart';

const _flutterblocUriPrefix = 'package:flutterbloc_kit/';
const _contextExtensions = {'ReadContext', 'WatchContext', 'SelectContext'};

/// Whether [node] calls one of flutterbloc_kit's BuildContext extension
/// methods named in [names].
///
/// A resolved call must come from one of the three extensions in
/// flutterbloc_kit, so a `select` on some other class in that package (or a
/// `watch` from DartNative's own `ListenableWatch`) does not match. An
/// unresolved call (the plugin running before `pub get`, say) is matched by
/// its receiver being DartNative's `BuildContext`.
bool _isContextCall(MethodInvocation node, Set<String> names) {
  if (!names.contains(node.methodName.name)) return false;
  final element = node.methodName.element;
  if (element != null) {
    final uri = element.library?.uri.toString() ?? '';
    final owner = element.enclosingElement?.name;
    return uri.startsWith(_flutterblocUriPrefix) &&
        _contextExtensions.contains(owner);
  }
  return isExactlyDartNativeType(node.realTarget?.staticType, 'BuildContext');
}

/// Where a call sits: in a build function, in a closure that is not a build
/// (an event handler), or in some other member (initState, a helper).
enum _Scope { build, handler, other }

/// Classifies the innermost function around [node].
///
/// A method named `build` or `buildWithChild` is a build. A closure whose
/// parameters include a `BuildContext` is a builder (`Builder`,
/// `BlocBuilder.builder`, `itemBuilder`) and counts as a build too; any other
/// closure is a handler.
_Scope _scopeOf(AstNode node) {
  var current = node.parent;
  while (current != null) {
    if (current is FunctionExpression) {
      final parameters = current.parameters?.parameters ?? const [];
      for (final parameter in parameters) {
        final type = parameter.declaredFragment?.element.type;
        if (isExactlyDartNativeType(type, 'BuildContext')) return _Scope.build;
      }
      return _Scope.handler;
    }
    if (current is MethodDeclaration) {
      final name = current.name.lexeme;
      return name == 'build' || name == 'buildWithChild'
          ? _Scope.build
          : _Scope.other;
    }
    if (current is FunctionDeclaration ||
        current is ConstructorDeclaration ||
        current is FieldDeclaration) {
      return _Scope.other;
    }
    current = current.parent;
  }
  return _Scope.other;
}

/// `context.watch` / `context.select` outside a build function.
class FlutterblocWatchOutsideBuild extends AnalysisRule {
  static final LintCode code = warning(
    'flutterbloc_watch_outside_build',
    "'context.watch' and 'context.select' subscribe the building widget; "
        'called here they read the value once and never rebuild anything.',
    correction:
        'Use context.read for a one-off read, or move the call into build '
        'or a builder callback.',
  );

  FlutterblocWatchOutsideBuild()
    : super(
        name: 'flutterbloc_watch_outside_build',
        description:
            'context.watch / context.select in an event handler, initState '
            'or a helper registers no rebuild (flutterbloc_kit 0.1.0).',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (context.isInTestDirectory) return;
    registry.addMethodInvocation(this, _WatchVisitor(this));
  }
}

class _WatchVisitor extends SimpleAstVisitor<void> {
  _WatchVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isContextCall(node, const {'watch', 'select'})) return;
    if (_scopeOf(node) == _Scope.build) return;
    rule.reportAtNode(node.methodName);
  }
}

/// `context.read<T>().state` rendered in build.
class FlutterblocReadStateInBuild extends AnalysisRule {
  static final LintCode code = warning(
    'flutterbloc_read_state_in_build',
    "'context.read<T>().state' in build is read once; the widget does not "
        'rebuild when the bloc emits, so what it shows goes stale.',
    correction:
        'Use context.watch<T>().state, context.select, or a BlocBuilder.',
  );

  FlutterblocReadStateInBuild()
    : super(
        name: 'flutterbloc_read_state_in_build',
        description:
            'context.read registers no dependency, so a state it exposes in '
            'build is never refreshed (flutterbloc_kit 0.1.0).',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (context.isInTestDirectory) return;
    registry.addMethodInvocation(this, _ReadStateVisitor(this));
  }
}

class _ReadStateVisitor extends SimpleAstVisitor<void> {
  _ReadStateVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isContextCall(node, const {'read'})) return;
    final parent = node.parent;
    if (parent is! PropertyAccess || parent.propertyName.name != 'state') {
      return;
    }
    if (_scopeOf(node) != _Scope.build) return;
    rule.reportAtNode(parent);
  }
}

/// Any `context.read` in build; opt-in because it is fine when the value only
/// feeds handlers declared in the same build.
class FlutterblocReadInBuild extends AnalysisRule {
  static const LintCode code = LintCode(
    'flutterbloc_read_in_build',
    "'context.read' in build reads once; if the value ends up rendered it "
        'goes stale, and a later refactor to render it is easy to get wrong.',
    correctionMessage:
        'Call context.read inside the event handler, or use context.watch / '
        'context.select for values that are rendered.',
  );

  FlutterblocReadInBuild()
    : super(
        name: 'flutterbloc_read_in_build',
        description:
            "provider's own guidance: read belongs in handlers, watch in "
            'build.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (context.isInTestDirectory) return;
    registry.addMethodInvocation(this, _ReadVisitor(this));
  }
}

class _ReadVisitor extends SimpleAstVisitor<void> {
  _ReadVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_isContextCall(node, const {'read'})) return;
    if (_scopeOf(node) != _Scope.build) return;
    rule.reportAtNode(node.methodName);
  }
}
