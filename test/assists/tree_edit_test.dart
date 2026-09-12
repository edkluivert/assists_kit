// ignore_for_file: non_constant_identifier_names

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/test_bases.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RemoveWidgetTest);
    defineReflectiveTests(SwapTest);
    defineReflectiveTests(ChildChildrenTest);
    defineReflectiveTests(MoveWidgetTest);
  });
}

const _nested = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text('hi'),
      ),
    );
  }
}
''';

@reflectiveTest
class RemoveWidgetTest extends AssistTest {
  Future<void> test_replacesWrapperWithItsChild() async {
    final out = await apply(_nested, 'Padding(', 'Remove this widget');
    expect(
      out,
      contains('''
    return Center(
      child: Text('hi'),
    );
'''),
    );
  }

  Future<void> test_alsoWorksForOneElementChildren() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [Text('hi')]);
  }
}
''';
    final out = await apply(code, 'Column(', 'Remove this widget');
    expect(out, contains("return Text('hi');"));
  }

  Future<void> test_keepsConstWhenRemovingAConstWrapper() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('hi'));
  }
}
''';
    final out = await apply(code, 'Center(', 'Remove this widget');
    expect(out, contains("return const Text('hi');"));
  }

  Future<void> test_notOfferedOnALeaf() async {
    final messages = await messagesAt(_nested, "Text('hi')");
    expect(messages, isNot(contains('Remove this widget')));
  }
}

@reflectiveTest
class SwapTest extends AssistTest {
  Future<void> test_swapWithParentKeepsEachWidgetsArguments() async {
    final out = await apply(_nested, 'Padding(', 'Swap with parent');
    expect(
      out,
      contains(
        "return Padding(padding: const EdgeInsets.all(8), "
        "child: Center(child: Text('hi')));",
      ),
    );
  }

  Future<void> test_swapWithChildFromTheOuterWidget() async {
    final out = await apply(_nested, 'Center(', 'Swap with child');
    expect(
      out,
      contains(
        "return Padding(padding: const EdgeInsets.all(8), "
        "child: Center(child: Text('hi')));",
      ),
    );
  }

  Future<void> test_notOfferedWhenTheChildHasNoChildSlot() async {
    final messages = await messagesAt(_nested, 'Padding(');
    expect(messages, isNot(contains('Swap with child')));
  }
}

@reflectiveTest
class ChildChildrenTest extends AssistTest {
  Future<void> test_childToChildren() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrapper(child: Text('hi'));
  }
}
''';
    final out = await apply(code, 'Wrapper(', 'Convert to children:');
    expect(out, contains("Wrapper(children: [Text('hi')])"));
  }

  Future<void> test_childrenToChild() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrapper(children: [Text('hi')]);
  }
}
''';
    final out = await apply(code, 'Wrapper(', 'Convert to child:');
    expect(out, contains("Wrapper(child: Text('hi'))"));
  }

  Future<void> test_childToChildrenNeedsAChildrenParameter() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(child: Icon(CupertinoIcons.plus)),
    );
  }
}
''';
    final messages = await messagesAt(code, 'FloatingActionButton(');
    expect(messages, isNot(contains('Convert to children:')));
  }

  Future<void> test_childrenToChildNeedsAChildParameter() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [Text('hi')]);
  }
}
''';
    // Column has no `child:` in the stub, so the conversion is not offered.
    final messages = await messagesAt(code, 'Column(');
    expect(messages, isNot(contains('Convert to child:')));
  }

  Future<void> test_childrenToChildNeedsExactlyOneElement() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [Text('a'), Text('b')]);
  }
}
''';
    final messages = await messagesAt(code, 'Column(');
    expect(messages, isNot(contains('Convert to child:')));
  }
}

@reflectiveTest
class MoveWidgetTest extends AssistTest {
  static const _list = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('a'),
        Text('b'),
        Text('c'),
      ],
    );
  }
}
''';

  Future<void> test_moveDownSwapsWithTheNextSibling() async {
    final out = await apply(_list, "Text('a')", 'Move widget down');
    expect(
      out,
      contains('''
        Text('b'),
        Text('a'),
        Text('c'),
'''),
    );
  }

  Future<void> test_moveUpSwapsWithThePreviousSibling() async {
    final out = await apply(_list, "Text('c')", 'Move widget up');
    expect(
      out,
      contains('''
        Text('a'),
        Text('c'),
        Text('b'),
'''),
    );
  }

  Future<void> test_firstElementCannotMoveUp() async {
    final messages = await messagesAt(_list, "Text('a')");
    expect(messages, isNot(contains('Move widget up')));
    expect(messages, contains('Move widget down'));
  }
}
