/// "Wrap with …" assists for DartNative widget creations.
library;

import 'package:analysis_server_plugin/edit/correction_utils.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/correction/fix_generators.dart'
    show ProducerGenerator;
import 'package:analyzer/dart/ast/ast.dart';
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

  /// Named arguments written before the slot, e.g. `padding: …, `.
  final String leading;

  const Wrapper(this.id, this.name, this.slot, {this.leading = ''});
}

const _wrappers = [
  Wrapper('center', 'Center', WrapSlot.child),
  Wrapper('container', 'Container', WrapSlot.child),
  Wrapper(
    'padding',
    'Padding',
    WrapSlot.child,
    leading: 'padding: const EdgeInsets.all(8.0), ',
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
    final creation = findWidgetCreation(node);
    if (creation == null) return;
    final text = wrapText(creation, _wrapper, utils);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(creation), text);
    });
  }
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
    final creation = findWidgetCreation(node);
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
/// Single-slot wrappers stay on one line and let the formatter reflow.
/// `children:` wrappers are written multi-line so the list reads naturally
/// before formatting, using the creation's own line indentation.
String wrapText(
  InstanceCreationExpression creation,
  Wrapper wrapper,
  CorrectionUtils utils,
) {
  final source = utils.getNodeText(creation);
  final name = wrapper.name;
  final leading = wrapper.leading;
  switch (wrapper.slot) {
    case WrapSlot.child:
      return '$name(${leading}child: $source)';
    case WrapSlot.builder:
      return '$name(${leading}builder: (context) => $source)';
    case WrapSlot.asyncBuilder:
      return '$name(${leading}builder: (context, snapshot) => $source)';
    case WrapSlot.children:
      final eol = utils.endOfLine;
      final one = utils.oneIndent;
      final indent = lineIndent(
        utils.getText(0, creation.offset),
        creation.offset,
      );
      // Continuation lines of the wrapped widget move in by two levels: one
      // for `children:` and one for the list element.
      final lines = source.split('\n');
      final inner = [
        lines.first,
        for (final line in lines.skip(1))
          line.trim().isEmpty ? line : '$one$one$line',
      ].join('\n');
      return '$name($eol'
          '$indent${one}children: [$eol'
          '$indent$one$one$inner,$eol'
          '$indent$one],$eol'
          '$indent)';
  }
}
