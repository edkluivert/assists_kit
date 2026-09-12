/// Warning rules for DartNative behaviours that fail silently or crash at
/// mount. Each rule encodes one fact from the DartNative widget reference or
/// from on-device observation; the rule's description says which.
library;

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../dartnative_widgets.dart';
import 'rule_support.dart';

/// `Scaffold.floatingActionButton` renders on Android only.
class FabSlotAndroidOnly extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_fab_slot_android_only',
    "'Scaffold.floatingActionButton' renders on Android only; on iOS the "
        'button does not appear.',
    correction:
        'Gate it as Platform.isAndroid ? fab : null and give iOS its own '
        'placement, or put the button in a Stack inside the body.',
  );

  FabSlotAndroidOnly()
    : super(
        name: 'dartnative_fab_slot_android_only',
        description:
            'The floatingActionButton slot renders on Android and shows '
            'nothing on iOS (observed on device, DartNative 1.0.0).',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _FabVisitor(this, context));
  }
}

class _FabVisitor extends CreationVisitor {
  _FabVisitor(super.rule, super.context) : super(className: 'Scaffold');

  @override
  void check(InstanceCreationExpression node) {
    final argument = namedArgument(node, 'floatingActionButton');
    if (argument == null) return;
    // `Platform.isAndroid ? fab : null` shows the author has handled iOS
    // deliberately; that is the recommended pattern, so stay quiet.
    if (_isPlatformGated(argument.argumentExpression)) return;
    rule.reportAtNode(argument);
  }

  static bool _isPlatformGated(Expression expression) {
    if (expression is! ConditionalExpression) return false;
    final condition = expression.condition.toSource();
    return condition.contains('Platform.isAndroid') ||
        condition.contains('Platform.isIOS') ||
        condition.contains('isIOS26');
  }
}

/// A `BarButtonItem` with `menu:` must be the only `AppBar.actions` entry.
class MenuActionMustBeAlone extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_menu_action_must_be_alone',
    "A 'BarButtonItem' with 'menu:' must be the only AppBar action; the app "
        'asserts at mount otherwise.',
    correction: 'Move the other actions into the menu as MenuAction entries.',
  );

  MenuActionMustBeAlone()
    : super(
        name: 'dartnative_menu_action_must_be_alone',
        description:
            'AppBar.actions containing a menu BarButtonItem beside other '
            'actions fails an assertion when the screen mounts.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _MenuVisitor(this, context));
  }
}

class _MenuVisitor extends CreationVisitor {
  _MenuVisitor(super.rule, super.context) : super(className: 'AppBar');

  @override
  void check(InstanceCreationExpression node) {
    final actions = namedArgument(node, 'actions')?.argumentExpression;
    if (actions is! ListLiteral || actions.elements.length < 2) return;
    for (final element in actions.elements) {
      if (element is InstanceCreationExpression &&
          isDartNativeCreation(element, 'BarButtonItem') &&
          namedArgument(element, 'menu') != null) {
        rule.reportAtNode(element);
      }
    }
  }
}

/// Only a uniform `Border` renders; per-side values are ignored.
class UniformBorderOnly extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_uniform_border_only',
    "Only a uniform 'Border' renders; DartNative reads 'top' and applies it "
        'to all four sides.',
    correction:
        "Use Border.all, or draw a single edge with a thin Positioned "
        'Container.',
  );

  UniformBorderOnly()
    : super(
        name: 'dartnative_uniform_border_only',
        description:
            'Border(top:, right:, bottom:, left:) with fewer than four '
            'identical sides does not render the way Flutter draws it.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _BorderVisitor(this, context));
  }
}

class _BorderVisitor extends CreationVisitor {
  static const _sides = ['top', 'right', 'bottom', 'left'];

  _BorderVisitor(super.rule, super.context) : super(className: 'Border');

  @override
  void check(InstanceCreationExpression node) {
    // Named constructors (Border.all, Border.fromBorderSide) are uniform.
    if (node.constructorName.name != null) return;
    final given = [
      for (final side in _sides)
        if (namedArgument(node, side) != null) side,
    ];
    if (given.isEmpty || given.length == _sides.length) return;
    rule.reportAtNode(node.constructorName);
  }
}

/// A `TextField` with a controller needs `onChanged` to mirror input back.
class MirrorTextController extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_mirror_text_controller',
    "'TextEditingController' is one-way in DartNative; typed text never "
        "reaches 'controller.text' without an 'onChanged' mirror.",
    correction: "Add 'onChanged: (value) => controller.text = value'.",
  );

  MirrorTextController()
    : super(
        name: 'dartnative_mirror_text_controller',
        description:
            'A TextField with a controller but no onChanged leaves the '
            'controller stale, so clear() and text= can no-op.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _TextFieldVisitor(this, context),
    );
  }
}

class _TextFieldVisitor extends CreationVisitor {
  _TextFieldVisitor(super.rule, super.context) : super(className: 'TextField');

  @override
  void check(InstanceCreationExpression node) {
    final controller = namedArgument(node, 'controller');
    if (controller == null || namedArgument(node, 'onChanged') != null) return;
    rule.reportAtNode(controller);
  }
}

/// `CustomPaint.size` must be finite.
class CustomPaintFiniteSize extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_custom_paint_finite_size',
    "'CustomPaint' paints once at mount against 'size'; an infinite "
        'dimension lands off-screen and the painter never re-runs.',
    correction: 'Use a concrete size, for example from MediaQuery.',
  );

  CustomPaintFiniteSize()
    : super(
        name: 'dartnative_custom_paint_finite_size',
        description:
            'CustomPaint(size: Size(double.infinity, …)) draws nothing '
            'visible in DartNative.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _CustomPaintVisitor(this, context),
    );
  }
}

class _CustomPaintVisitor extends CreationVisitor {
  _CustomPaintVisitor(super.rule, super.context)
    : super(className: 'CustomPaint');

  @override
  void check(InstanceCreationExpression node) {
    final size = namedArgument(node, 'size');
    if (size == null) return;
    final finder = _InfinityFinder();
    size.argumentExpression.accept(finder);
    if (finder.found != null) rule.reportAtNode(finder.found!);
  }
}

/// Records the first `double.infinity` reference in a subtree.
class _InfinityFinder extends RecursiveAstVisitor<void> {
  AstNode? found;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (found == null &&
        node.prefix.name == 'double' &&
        node.identifier.name == 'infinity') {
      found = node;
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// `Positioned` must be the outermost wrapper of a `Stack` child.
class PositionedMustBeOutermost extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_positioned_must_be_outermost',
    "'Positioned' must be the outermost wrapper of a Stack child; this "
        'wrapper above it is dropped.',
    correction: 'Move the wrapper inside the Positioned child.',
  );

  PositionedMustBeOutermost()
    : super(
        name: 'dartnative_positioned_must_be_outermost',
        description:
            'A widget wrapping a Positioned inside Stack.children is '
            'discarded by the DartNative Stack.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _StackVisitor(this, context));
  }
}

class _StackVisitor extends CreationVisitor {
  _StackVisitor(super.rule, super.context) : super(className: 'Stack');

  @override
  void check(InstanceCreationExpression node) {
    final list = childrenList(node);
    if (list == null) return;
    for (final element in list.elements) {
      if (element is! InstanceCreationExpression) continue;
      if (isDartNativeCreation(element, 'Positioned')) continue;
      final inner = childArgument(element)?.argumentExpression;
      if (inner is InstanceCreationExpression &&
          isDartNativeCreation(inner, 'Positioned')) {
        rule.reportAtNode(element.constructorName);
      }
    }
  }
}

/// `SnackBarAction.onPressed` is not wired.
class SnackBarActionNotWired extends AnalysisRule {
  static final LintCode code = warning(
    'dartnative_snackbar_action_not_wired',
    "'SnackBarAction.onPressed' is not wired in DartNative; the label shows "
        'but tapping it does nothing.',
    correction: 'Use showToast, or a Button in your own overlay.',
  );

  SnackBarActionNotWired()
    : super(
        name: 'dartnative_snackbar_action_not_wired',
        description:
            'SnackBar lowers to a native toast whose action callback is not '
            'connected.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _SnackBarActionVisitor(this, context),
    );
  }
}

class _SnackBarActionVisitor extends CreationVisitor {
  _SnackBarActionVisitor(super.rule, super.context)
    : super(className: 'SnackBarAction');

  @override
  void check(InstanceCreationExpression node) {
    final onPressed = namedArgument(node, 'onPressed');
    if (onPressed != null) rule.reportAtNode(onPressed);
  }
}

/// `Offstage` unmounts its child; opt-in lint because it is sometimes wanted.
class OffstageLosesState extends AnalysisRule {
  static const LintCode code = LintCode(
    'dartnative_offstage_loses_state',
    "'Offstage' unmounts its child in DartNative, so the child's State is "
        'lost.',
    correctionMessage:
        'Use IndexedStack or Visibility(maintainState: true) '
        'to keep the state.',
  );

  OffstageLosesState()
    : super(
        name: 'dartnative_offstage_loses_state',
        description:
            'Flutter keeps an offstage child mounted at zero size; DartNative '
            'unmounts it.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(
      this,
      _OffstageVisitor(this, context),
    );
  }
}

class _OffstageVisitor extends CreationVisitor {
  _OffstageVisitor(super.rule, super.context) : super(className: 'Offstage');

  @override
  void check(InstanceCreationExpression node) {
    rule.reportAtNode(node.constructorName);
  }
}

/// Every rule that is on by default.
List<AnalysisRule> get warningRules => [
  FabSlotAndroidOnly(),
  MenuActionMustBeAlone(),
  UniformBorderOnly(),
  MirrorTextController(),
  CustomPaintFiniteSize(),
  PositionedMustBeOutermost(),
  SnackBarActionNotWired(),
];

/// Rules that must be enabled in analysis_options.yaml.
List<AnalysisRule> get lintRules => [OffstageLosesState()];
