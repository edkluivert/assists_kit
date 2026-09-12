/// "Convert to StatelessWidget" for a DartNative `StatefulWidget` whose State
/// has no lifecycle overrides and never calls `setState`.
library;

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'dartnative_widgets.dart';
import 'source_text.dart';

const _lifecycleMethods = {
  'initState',
  'dispose',
  'didUpdateWidget',
  'didChangeDependencies',
  'deactivate',
  'activate',
  'setState',
};

class ConvertToStatelessWidget extends ResolvedCorrectionProducer {
  static const _kind = AssistKind(
    'dartnative.assist.convert.toStatelessWidget',
    30,
    'Convert to StatelessWidget',
  );

  ConvertToStatelessWidget({required super.context});

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
        !isExactlyDartNativeType(superclass.type, 'StatefulWidget')) {
      return;
    }
    final widgetElement = classDecl.declaredFragment?.element;
    if (widgetElement == null) return;
    final body = classDecl.body;
    if (body is! BlockClassBody) return;

    MethodDeclaration? createState;
    for (final member in body.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'createState') {
        createState = member;
      }
    }
    if (createState == null) return;

    final stateDecl = _findStateClass(classDecl, widgetElement);
    if (stateDecl == null) return;
    if (stateDecl.withClause != null || stateDecl.implementsClause != null) {
      return;
    }
    final stateBody = stateDecl.body;
    if (stateBody is! BlockClassBody) return;
    if (!_stateIsConvertible(stateDecl, stateBody)) return;
    final stateElement = stateDecl.declaredFragment?.element;
    if (stateElement == null) return;

    final eol = utils.endOfLine;
    final headerSource = utils.getText(
      classDecl.offset,
      superclass.offset - classDecl.offset,
    );
    final afterSuperSource = utils.getText(
      superclass.end,
      body.leftBracket.end - superclass.end,
    );

    final buffer = StringBuffer()
      ..write(headerSource)
      ..write('StatelessWidget')
      ..write(afterSuperSource);
    for (final member in body.members) {
      if (member == createState) continue;
      buffer
        ..write(eol)
        ..write(memberSource(utils, member))
        ..write(eol);
    }
    for (final member in stateBody.members) {
      buffer
        ..write(eol)
        ..write(_movedMemberSource(member, stateElement))
        ..write(eol);
    }
    buffer.write('}');

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(classDecl), buffer.toString());
      builder.addDeletion(range.deletionRange(stateDecl));
    });
  }

  ClassDeclaration? _findStateClass(
    ClassDeclaration widgetDecl,
    ClassElement widgetElement,
  ) {
    final unit = widgetDecl.parent;
    if (unit is! CompilationUnit) return null;
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration || declaration == widgetDecl) {
        continue;
      }
      final superType = declaration.extendsClause?.superclass.type;
      if (superType is! InterfaceType ||
          !isExactlyDartNativeType(superType, 'State')) {
        continue;
      }
      final args = superType.typeArguments;
      if (args.isNotEmpty) {
        final first = args.first;
        if (first is InterfaceType && first.element == widgetElement) {
          return declaration;
        }
      }
    }
    return null;
  }

  bool _stateIsConvertible(ClassDeclaration stateDecl, BlockClassBody body) {
    for (final member in body.members) {
      if (member is ConstructorDeclaration) return false;
      if (member is MethodDeclaration &&
          _lifecycleMethods.contains(member.name.lexeme)) {
        return false;
      }
    }
    final finder = _SetStateFinder();
    stateDecl.accept(finder);
    return !finder.found;
  }

  /// [memberSource] with every `widget.` qualifier removed.
  String _movedMemberSource(ClassMember member, ClassElement stateElement) {
    final finder = _WidgetQualifierFinder(stateElement);
    member.accept(finder);
    return memberSourceWithEdits(utils, member, finder.edits);
  }
}

class _SetStateFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') found = true;
    super.visitMethodInvocation(node);
  }
}

/// Finds `widget.` qualifiers where `widget` is the State's own getter and
/// records a deletion of the `widget.` text.
class _WidgetQualifierFinder extends RecursiveAstVisitor<void> {
  final ClassElement stateElement;
  final List<TextEdit> edits = [];

  _WidgetQualifierFinder(this.stateElement);

  bool _isStateWidgetGetter(SimpleIdentifier id) {
    if (id.name != 'widget') return false;
    final element = id.element;
    if (element is! PropertyAccessorElement) return false;
    return isStateElement(element.enclosingElement as InterfaceElement?);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_isStateWidgetGetter(node.prefix)) {
      edits.add(TextEdit.delete(node.prefix.offset, node.identifier.offset));
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier && _isStateWidgetGetter(target)) {
      edits.add(TextEdit.delete(target.offset, node.propertyName.offset));
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier && _isStateWidgetGetter(target)) {
      edits.add(TextEdit.delete(target.offset, node.methodName.offset));
    }
    super.visitMethodInvocation(node);
  }
}
