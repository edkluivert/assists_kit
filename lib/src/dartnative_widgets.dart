/// Type and AST helpers that recognise DartNative widgets.
///
/// Everything here mirrors what the analysis server's `flutter.dart`
/// utilities do for Flutter, but keyed on `package:dartnative/…` instead of
/// `package:flutter/src/widgets/framework.dart`.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

const _dartnativeUriPrefix = 'package:dartnative/';

/// Whether [element] is declared in the `dartnative` package.
bool isDartNativeElement(Element? element) {
  final uri = element?.library?.uri.toString();
  return uri != null && uri.startsWith(_dartnativeUriPrefix);
}

/// Whether [element] is exactly DartNative's class called [name].
bool isDartNativeClass(InterfaceElement? element, String name) =>
    element != null && element.name == name && isDartNativeElement(element);

/// Whether [element] is, or extends, DartNative's class called [name].
bool isOrExtendsDartNative(InterfaceElement? element, String name) {
  if (element == null) return false;
  if (isDartNativeClass(element, name)) return true;
  for (final supertype in element.allSupertypes) {
    if (isDartNativeClass(supertype.element, name)) return true;
  }
  return false;
}

/// Whether [type] is a DartNative `Widget` (or subtype).
bool isWidgetType(DartType? type) =>
    type is InterfaceType && isOrExtendsDartNative(type.element, 'Widget');

/// Whether [type] is exactly DartNative's class called [name].
bool isExactlyDartNativeType(DartType? type, String name) =>
    type is InterfaceType && isDartNativeClass(type.element, name);

/// Whether [creation] instantiates exactly DartNative's class called [name].
bool isDartNativeCreation(InstanceCreationExpression creation, String name) =>
    isExactlyDartNativeType(creation.staticType, name);

/// Whether [element] is DartNative's `State` class.
bool isStateElement(InterfaceElement? element) =>
    isDartNativeClass(element, 'State');

/// Finds the widget creation expression the cursor is "on".
///
/// Walks up from [node]: a cursor on the constructor name (`Text` in
/// `Text('hi')`) or anywhere inside the argument list resolves to that
/// creation; the walk stops at function bodies so a cursor inside an
/// `onPressed` closure does not pick up the enclosing button.
InstanceCreationExpression? findWidgetCreation(AstNode? node) {
  var current = node;
  if (current is SimpleIdentifier && current.parent is NamedType) {
    current = current.parent;
  }
  if (current is NamedType && current.parent is ConstructorName) {
    current = current.parent!.parent;
  }
  while (current != null) {
    if (current is InstanceCreationExpression &&
        isWidgetType(current.staticType)) {
      return current;
    }
    if (current is FunctionBody ||
        current is Statement ||
        current is ClassMember ||
        current is CompilationUnit) {
      return null;
    }
    current = current.parent;
  }
  return null;
}

/// The named argument called [name] of [creation], if present.
NamedArgument? namedArgument(InstanceCreationExpression creation, String name) {
  for (final argument in creation.argumentList.arguments) {
    if (argument is NamedArgument && argument.name.lexeme == name) {
      return argument;
    }
  }
  return null;
}

/// The `child:` argument of a widget creation, if any.
NamedArgument? childArgument(InstanceCreationExpression creation) =>
    namedArgument(creation, 'child');

/// The `children:` argument of a widget creation, if any.
NamedArgument? childrenArgument(InstanceCreationExpression creation) =>
    namedArgument(creation, 'children');

/// The `children:` list literal of a widget creation, if any.
ListLiteral? childrenList(InstanceCreationExpression creation) {
  final expression = childrenArgument(creation)?.argumentExpression;
  return expression is ListLiteral ? expression : null;
}

/// The single widget a creation wraps: its `child:` expression, or the only
/// element of a one-element `children:` list. Null when there is no single
/// wrapped widget.
Expression? singleWrappedWidget(InstanceCreationExpression creation) {
  final child = childArgument(creation);
  if (child != null && isWidgetType(child.argumentExpression.staticType)) {
    return child.argumentExpression;
  }
  final list = childrenList(creation);
  if (list != null && list.elements.length == 1) {
    final only = list.elements.single;
    if (only is Expression && isWidgetType(only.staticType)) {
      return only;
    }
  }
  return null;
}

/// The class declaration whose header (from `class` to `{`) contains
/// [offset], or null. Used so the convert assists only show when the cursor
/// is on the class line, matching Flutter's behaviour.
ClassDeclaration? classDeclarationAtHeader(AstNode? node, int offset) {
  var current = node;
  while (current != null) {
    if (current is ClassDeclaration) {
      final body = current.body;
      if (body is BlockClassBody &&
          offset >= current.offset &&
          offset <= body.leftBracket.offset) {
        return current;
      }
      return null;
    }
    if (current is ClassMember) return null;
    current = current.parent;
  }
  return null;
}
