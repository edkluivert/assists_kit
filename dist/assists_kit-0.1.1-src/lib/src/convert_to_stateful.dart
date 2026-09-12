/// "Convert to StatefulWidget" for classes extending DartNative's
/// `StatelessWidget`.
///
/// Mirrors the Flutter assist: constructors and final fields stay on the
/// widget; every other member moves to a new `_XState extends State<X>`,
/// and references to the widget's fields inside moved members become
/// `widget.field`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';
import 'source_text.dart';

class ConvertToStatefulWidget extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.convert.toStatefulWidget',
    30,
    'Convert to StatefulWidget',
  );

  ConvertToStatefulWidget({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final classDecl = classDeclarationAtHeader(node, selectionOffset);
    if (classDecl == null) return;
    final superclass = classDecl.extendsClause?.superclass;
    if (superclass == null ||
        !isExactlyDartNativeType(superclass.type, 'StatelessWidget')) {
      return;
    }
    final classElement = classDecl.declaredFragment?.element;
    if (classElement == null) return;
    final body = classDecl.body;
    if (body is! BlockClassBody) return;

    final kept = <ClassMember>[];
    final moved = <ClassMember>[];
    for (final member in body.members) {
      if (_staysOnWidget(member)) {
        kept.add(member);
      } else {
        moved.add(member);
      }
    }

    final eol = utils.endOfLine;
    final one = utils.oneIndent;
    final className = classDecl.namePart.typeName.lexeme;
    final typeParams = classDecl.namePart.typeParameters;
    final typeParamsText = typeParams == null
        ? ''
        : utils.getNodeText(typeParams);
    final typeArgsText = typeParams == null
        ? ''
        : '<${typeParams.typeParameters.map((p) => p.name.lexeme).join(', ')}>';
    final stateName = '_${className}State';

    // Widget class: header with StatefulWidget, kept members, createState.
    final headerSource = utils.getText(
      classDecl.offset,
      superclass.offset - classDecl.offset,
    );
    final afterSuperSource = utils.getText(
      superclass.end,
      body.leftBracket.end - superclass.end,
    );
    final widgetBuffer = StringBuffer()
      ..write(headerSource)
      ..write('StatefulWidget')
      ..write(afterSuperSource);
    for (final member in kept) {
      widgetBuffer
        ..write(eol)
        ..write(memberSource(utils, member))
        ..write(eol);
    }
    widgetBuffer
      ..write(eol)
      ..write('$one@override$eol')
      ..write(
        '${one}State<$className$typeArgsText> createState() => $stateName$typeArgsText();$eol',
      )
      ..write('}');

    // Names of instance fields that stay on the widget; references to these
    // from moved members become `widget.name`.
    final keptFieldNames = <String>{
      for (final member in kept)
        if (member is FieldDeclaration && !member.isStatic)
          for (final variable in member.fields.variables) variable.name.lexeme,
    };

    // State class: moved members with `widget.` / `ClassName.` prefixes.
    final stateBuffer = StringBuffer()
      ..write(
        'class $stateName$typeParamsText extends State<$className$typeArgsText> {',
      );
    for (final member in moved) {
      stateBuffer
        ..write(eol)
        ..write(
          _movedMemberSource(member, classElement, className, keptFieldNames),
        )
        ..write(eol);
    }
    stateBuffer.write('}');

    final replacement = '$widgetBuffer$eol$eol$stateBuffer';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(classDecl), replacement);
    });
  }

  bool _staysOnWidget(ClassMember member) {
    if (member is ConstructorDeclaration) return true;
    if (member is FieldDeclaration) {
      return member.isStatic || member.fields.isFinal || member.fields.isConst;
    }
    if (member is MethodDeclaration) return member.isStatic;
    return false;
  }

  /// [memberSource] with `widget.` inserted before every reference to an
  /// instance field that stays on the widget class, and `ClassName.` before
  /// every reference to a static member of it.
  String _movedMemberSource(
    ClassMember member,
    ClassElement classElement,
    String className,
    Set<String> keptFieldNames,
  ) {
    final finder = _WidgetMemberReferenceFinder(
      classElement,
      className,
      keptFieldNames,
    );
    member.accept(finder);
    return memberSourceWithEdits(utils, member, finder.edits);
  }
}

/// Collects rewrites for unqualified references, inside a moved member, to
/// members that remain on the widget class.
class _WidgetMemberReferenceFinder extends RecursiveAstVisitor<void> {
  final ClassElement classElement;
  final String className;
  final Set<String> keptFieldNames;
  final List<TextEdit> edits = [];

  _WidgetMemberReferenceFinder(
    this.classElement,
    this.className,
    this.keptFieldNames,
  );

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    super.visitSimpleIdentifier(node);
    if (_isQualified(node) || node.parent is Label) return;
    final element = node.element;
    if (element == null || element.enclosingElement != classElement) return;

    String? prefix;
    if (element is FieldElement) {
      if (element.isStatic) {
        prefix = '$className.';
      } else if (keptFieldNames.contains(element.name)) {
        prefix = 'widget.';
      }
    } else if (element is PropertyAccessorElement) {
      final variable = element.variable;
      if (element.isStatic) {
        prefix = '$className.';
      } else if (variable is FieldElement &&
          keptFieldNames.contains(variable.name)) {
        prefix = 'widget.';
      }
    } else if (element is MethodElement && element.isStatic) {
      prefix = '$className.';
    }
    if (prefix == null) return;

    // `'$name'` must become `'${widget.name}'`, not `'$widget.name'`.
    final parent = node.parent;
    if (parent is InterpolationExpression && parent.rightBracket == null) {
      edits.add(
        TextEdit(parent.offset, parent.length, '\${$prefix${node.name}}'),
      );
    } else {
      edits.add(TextEdit.insert(node.offset, prefix));
    }
  }

  bool _isQualified(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is PrefixedIdentifier && parent.identifier == node) return true;
    if (parent is PropertyAccess && parent.propertyName == node) return true;
    if (parent is MethodInvocation &&
        parent.methodName == node &&
        parent.target != null) {
      return true;
    }
    if (parent is ConstructorFieldInitializer && parent.fieldName == node) {
      return true;
    }
    return false;
  }
}
