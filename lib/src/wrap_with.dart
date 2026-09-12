/// "Wrap with …" assists for DartNative widget creations.
library;

import 'package:analysis_server_plugin/edit/correction_utils.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/correction/fix_generators.dart'
    show ProducerGenerator;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';
import 'source_text.dart';

const _priority = 30;

/// How a wrapper receives the wrapped widget.
enum WrapSlot {
  /// `Name(child: …)`
  child,

  /// `Name(children: [ … ])`, written multi-line.
  children,

  /// `Name(builder: (context) => …)`
  builder,

  /// `Name(<leading>builder: (context, snapshot) => …)`
  asyncBuilder,
}

/// A wrapper widget the "Wrap with" assists can offer.
class Wrapper {
  final String id;
  final String name;
  final WrapSlot slot;

  /// Named arguments written before the slot, e.g. `padding: …, `. The
  /// marker `{const}` becomes `const ` outside a constant context and
  /// nothing inside one, where the keyword would be redundant.
  final String leading;

  const Wrapper(this.id, this.name, this.slot, {this.leading = ''});

  /// Whether the slot takes a closure, which can never be part of a
  /// constant expression.
  bool get takesClosure =>
      slot == WrapSlot.builder || slot == WrapSlot.asyncBuilder;
}

const _wrappers = [
  Wrapper('center', 'Center', WrapSlot.child),
  Wrapper('container', 'Container', WrapSlot.child),
  Wrapper(
    'padding',
    'Padding',
    WrapSlot.child,
    leading: 'padding: {const}EdgeInsets.all(8.0), ',
  ),
  Wrapper('sizedBox', 'SizedBox', WrapSlot.child),
  Wrapper('expanded', 'Expanded', WrapSlot.child),
  Wrapper('flexible', 'Flexible', WrapSlot.child),
  Wrapper('safeArea', 'SafeArea', WrapSlot.child),
  Wrapper('gestureDetector', 'GestureDetector', WrapSlot.child),
  Wrapper('glassEffectContainer', 'GlassEffectContainer', WrapSlot.child),
  Wrapper('column', 'Column', WrapSlot.children),
  Wrapper('row', 'Row', WrapSlot.children),
  Wrapper('stack', 'Stack', WrapSlot.children),
  Wrapper('builder', 'Builder', WrapSlot.builder),
  Wrapper(
    'futureBuilder',
    'FutureBuilder',
    WrapSlot.asyncBuilder,
    leading: 'future: future, ',
  ),
  Wrapper(
    'streamBuilder',
    'StreamBuilder',
    WrapSlot.asyncBuilder,
    leading: 'stream: stream, ',
  ),
  Wrapper(
    'valueListenableBuilder',
    'ValueListenableBuilder',
    WrapSlot.asyncBuilder,
    leading: 'valueListenable: valueListenable, ',
  ),
];

/// One generator per wrapper, in the order they are offered.
final List<ProducerGenerator> wrapProducerGenerators = [
  for (final wrapper in _wrappers)
    ({required CorrectionProducerContext context}) =>
        WrapWith(wrapper, context: context),
];

/// Wraps the selected widget creation in a fixed wrapper widget.
class WrapWith extends ResolvedCorrectionProducer {
  final Wrapper _wrapper;

  WrapWith(this._wrapper, {required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => AssistKind(
    'dartnative.assist.wrap.${_wrapper.id}',
    _priority,
    'Wrap with ${_wrapper.name}',
  );

  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (selectionLength > 0 && _wrapper.slot == WrapSlot.children) {
      final siblings = selectedSiblings();
      if (siblings != null) return _wrapSiblings(builder, siblings);
    }
    final creation = findWidgetExpression(node);
    if (creation == null) return;
    final inConstContext = creation.inConstantContext;
    final text = wrapText(creation, _wrapper, utils);

    // A closure cannot live inside a constant expression. Drop the `const`
    // that establishes the context; the wrapped widget keeps its own
    // constness because [wrapText] writes `const` on it in that case.
    Token? constToDrop;
    if (inConstContext && _wrapper.takesClosure) {
      constToDrop = enclosingConstKeyword(creation);
      if (constToDrop == null) return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(creation), text);
      if (constToDrop != null) {
        builder.addDeletion(range.startStart(constToDrop, constToDrop.next!));
      }
    });
  }

  /// The widget elements of the innermost list literal that the selection
  /// touches, when it touches at least two. Null otherwise.
  List<Expression>? selectedSiblings() {
    AstNode? current = node;
    while (current != null && current is! ListLiteral) {
      if (current is FunctionBody || current is Statement) return null;
      current = current.parent;
    }
    if (current is! ListLiteral) return null;
    final selectionEnd = selectionOffset + selectionLength;
    final selected = [
      for (final element in current.elements)
        if (element is Expression &&
            element.end > selectionOffset &&
            element.offset < selectionEnd)
          element,
    ];
    if (selected.length < 2) return null;
    if (!selected.every((e) => isWidgetType(e.staticType))) return null;
    return selected;
  }

  Future<void> _wrapSiblings(
    ChangeBuilder builder,
    List<Expression> siblings,
  ) async {
    final first = siblings.first;
    final last = siblings.last;
    final eol = utils.endOfLine;
    final one = utils.oneIndent;
    final indent = lineIndent(utils.getText(0, first.offset), first.offset);
    final items = [
      for (final sibling in siblings)
        reindentContinuationLines(utils.getNodeText(sibling), one * 2),
    ].join(',$eol$indent$one$one');
    final text =
        '${_wrapper.name}($eol'
        '$indent${one}children: [$eol'
        '$indent$one$one$items,$eol'
        '$indent$one],$eol'
        '$indent)';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.startEnd(first, last), text);
    });
  }
}

/// The `const` keyword that puts [expression] in a constant context: on an
/// enclosing instance creation or collection literal. Null when the context
/// comes from something that cannot simply lose the keyword, such as a
/// `const` variable declaration.
Token? enclosingConstKeyword(Expression expression) {
  AstNode? current = expression.parent;
  while (current != null) {
    if (current is InstanceCreationExpression) {
      final keyword = current.keyword;
      if (keyword != null && keyword.keyword == Keyword.CONST) return keyword;
    } else if (current is TypedLiteral) {
      final keyword = current.constKeyword;
      if (keyword != null) return keyword;
    } else if (current is VariableDeclarationList ||
        current is Annotation ||
        current is ConstantPattern ||
        current is FunctionBody) {
      return null;
    }
    current = current.parent;
  }
  return null;
}

/// "Wrap with widget…": the wrapper name is a linked edit the user types.
class WrapWithWidget extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.wrap.generic',
    _priority - 1,
    'Wrap with widget...',
  );

  WrapWithWidget({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final creation = findWidgetExpression(node);
    if (creation == null) return;
    final source = utils.getNodeText(creation);
    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.node(creation), (builder) {
        builder.addSimpleLinkedEdit('WIDGET', 'widget');
        builder.write('(child: ');
        builder.write(source);
        builder.write(')');
      });
    });
  }
}

/// The replacement text for wrapping [creation] in [wrapper].
///
/// Mirrors the analysis server's Flutter wrap: the wrapped source is kept
/// verbatim (an explicit `const` stays on the inner widget, nothing is
/// hoisted), a `{const}` marker in [Wrapper.leading] is dropped inside a
/// constant context, and a multi-line widget is laid out on its own lines at
/// the creation's indentation.
String wrapText(Expression creation, Wrapper wrapper, CorrectionUtils utils) {
  final inConstContext = creation.inConstantContext;
  var source = utils.getNodeText(creation);
  // Wrapping with a closure removes the surrounding const context, so an
  // implicitly-const widget must become explicitly const to stay const.
  if (inConstContext &&
      wrapper.takesClosure &&
      creation is InstanceCreationExpression &&
      creation.keyword == null) {
    source = 'const $source';
  }
  final name = wrapper.name;
  final leading = wrapper.leading.replaceAll(
    '{const}',
    inConstContext ? '' : 'const ',
  );
  final slotText = switch (wrapper.slot) {
    WrapSlot.child || WrapSlot.children => 'child: ',
    WrapSlot.builder => 'builder: (context) => ',
    WrapSlot.asyncBuilder => 'builder: (context, snapshot) => ',
  };

  final eol = utils.endOfLine;
  final one = utils.oneIndent;
  final indent = lineIndent(utils.getText(0, creation.offset), creation.offset);
  if (wrapper.slot == WrapSlot.children) {
    return '$name($eol'
        '$indent$one${leading}children: [$eol'
        '$indent$one$one${reindentContinuationLines(source, one * 2)},$eol'
        '$indent$one],$eol'
        '$indent)';
  }
  if (!source.contains('\n')) {
    return '$name($leading$slotText$source)';
  }
  return '$name($eol'
      '$indent$one$leading$slotText${reindentContinuationLines(source, one)},$eol'
      '$indent)';
}
