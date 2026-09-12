// ignore_for_file: non_constant_identifier_names

import 'package:dartnative_assists/src/rules/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/test_bases.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FabSlotAndroidOnlyTest);
    defineReflectiveTests(MenuActionMustBeAloneTest);
    defineReflectiveTests(UniformBorderOnlyTest);
    defineReflectiveTests(MirrorTextControllerTest);
    defineReflectiveTests(CustomPaintFiniteSizeTest);
    defineReflectiveTests(PositionedMustBeOutermostTest);
    defineReflectiveTests(SnackBarActionNotWiredTest);
    defineReflectiveTests(OffstageLosesStateTest);
  });
}

@reflectiveTest
class FabSlotAndroidOnlyTest extends RuleTest {
  @override
  void setUp() {
    rule = FabSlotAndroidOnly();
    super.setUp();
  }

  Future<void> test_reportsTheSlot() => assertWarning(
    '''
Widget build() => Scaffold(
  floatingActionButton: FloatingActionButton(child: Icon(CupertinoIcons.plus)),
);
''',
    'floatingActionButton: FloatingActionButton(child: '
        'Icon(CupertinoIcons.plus))',
  );

  Future<void> test_quietWithoutTheSlot() =>
      assertClean("Widget build() => Scaffold(body: Text('x'));");
}

@reflectiveTest
class MenuActionMustBeAloneTest extends RuleTest {
  @override
  void setUp() {
    rule = MenuActionMustBeAlone();
    super.setUp();
  }

  Future<void> test_reportsAMenuItemWithSiblings() => assertWarning(
    '''
Widget build() => AppBar(actions: [
  BarButtonItem(title: 'Info', onPressed: () {}),
  BarButtonItem(icon: 'ellipsis', menu: [MenuAction(title: 'A', onTap: () {})]),
]);
''',
    "BarButtonItem(icon: 'ellipsis', menu: [MenuAction(title: 'A', "
        'onTap: () {})])',
  );

  Future<void> test_quietWhenTheMenuItemIsAlone() => assertClean('''
Widget build() => AppBar(actions: [
  BarButtonItem(icon: 'ellipsis', menu: [MenuAction(title: 'A', onTap: () {})]),
]);
''');
}

@reflectiveTest
class UniformBorderOnlyTest extends RuleTest {
  @override
  void setUp() {
    rule = UniformBorderOnly();
    super.setUp();
  }

  Future<void> test_reportsASingleSide() => assertWarning(
    'final d = BoxDecoration(border: Border(bottom: BorderSide(width: 1)));',
    'Border',
  );

  Future<void> test_quietForBorderAll() =>
      assertClean('final d = BoxDecoration(border: Border.all(width: 1));');

  Future<void> test_quietWhenAllFourSidesAreGiven() => assertClean('''
final s = BorderSide(width: 1);
final d = BoxDecoration(border: Border(top: s, right: s, bottom: s, left: s));
''');
}

@reflectiveTest
class MirrorTextControllerTest extends RuleTest {
  @override
  void setUp() {
    rule = MirrorTextController();
    super.setUp();
  }

  Future<void> test_reportsControllerWithoutOnChanged() => assertWarning('''
final c = TextEditingController();
Widget build() => TextField(controller: c);
''', 'controller: c');

  Future<void> test_quietWithOnChanged() => assertClean('''
final c = TextEditingController();
Widget build() => TextField(controller: c, onChanged: (v) => c.text = v);
''');
}

@reflectiveTest
class CustomPaintFiniteSizeTest extends RuleTest {
  @override
  void setUp() {
    rule = CustomPaintFiniteSize();
    super.setUp();
  }

  Future<void> test_reportsInfinity() => assertWarning(
    'Widget build() => CustomPaint(size: Size(double.infinity, 200));',
    'double.infinity',
  );

  Future<void> test_quietForConcreteSize() =>
      assertClean('Widget build() => CustomPaint(size: Size(300, 200));');
}

@reflectiveTest
class PositionedMustBeOutermostTest extends RuleTest {
  @override
  void setUp() {
    rule = PositionedMustBeOutermost();
    super.setUp();
  }

  Future<void> test_reportsAWrapperAbovePositioned() => assertWarning('''
Widget build() => Stack(children: [
  Text('base'),
  Padding(padding: EdgeInsets.all(8), child: Positioned(top: 0, child: Text('x'))),
]);
''', 'Padding');

  Future<void> test_quietWhenPositionedIsOutermost() => assertClean('''
Widget build() => Stack(children: [
  Text('base'),
  Positioned(top: 0, child: Padding(padding: EdgeInsets.all(8), child: Text('x'))),
]);
''');
}

@reflectiveTest
class SnackBarActionNotWiredTest extends RuleTest {
  @override
  void setUp() {
    rule = SnackBarActionNotWired();
    super.setUp();
  }

  Future<void> test_reportsOnPressed() => assertWarning(
    "final a = SnackBarAction(label: 'Undo', onPressed: () {});",
    'onPressed: () {}',
  );
}

@reflectiveTest
class OffstageLosesStateTest extends RuleTest {
  @override
  void setUp() {
    rule = OffstageLosesState();
    super.setUp();
  }

  Future<void> test_reportsOffstage() => assertWarning(
    "Widget build() => Offstage(child: Text('x'));",
    'Offstage',
  );
}
