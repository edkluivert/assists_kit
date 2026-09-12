// ignore_for_file: non_constant_identifier_names

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/test_bases.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WrapTest);
  });
}

@reflectiveTest
class WrapTest extends AssistTest {
  static const _screen = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('hi'),
    );
  }
}
''';

  Future<void> test_offersEveryWrapperOnAWidget() async {
    final messages = await messagesAt(_screen, "Text('hi')");
    expect(
      messages,
      containsAll([
        'Wrap with Center',
        'Wrap with Container',
        'Wrap with Padding',
        'Wrap with SizedBox',
        'Wrap with Expanded',
        'Wrap with Flexible',
        'Wrap with SafeArea',
        'Wrap with GestureDetector',
        'Wrap with GlassEffectContainer',
        'Wrap with Column',
        'Wrap with Row',
        'Wrap with Stack',
        'Wrap with Builder',
        'Wrap with FutureBuilder',
        'Wrap with StreamBuilder',
        'Wrap with ValueListenableBuilder',
        'Wrap with widget...',
      ]),
    );
  }

  Future<void> test_cursorOnConstructorNameCountsAsOnTheWidget() async {
    final messages = await messagesAt(_screen, 'Text');
    expect(messages, contains('Wrap with Container'));
  }

  Future<void> test_cursorOnAnArgumentLabelTargetsThatArgumentsWidget() async {
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
    final out = await apply(code, 'floatingActionButton:', 'Wrap with Center');
    expect(
      out,
      contains(
        'floatingActionButton: Center(child: FloatingActionButton('
        'child: Icon(CupertinoIcons.plus))),',
      ),
    );
    expect(out, isNot(contains('Center(child: Scaffold(')));
  }

  Future<void> test_nothingOnAClassHeader() async {
    final messages = await messagesAt(_screen, 'class Home');
    expect(messages, isNot(contains('Wrap with Container')));
  }

  Future<void> test_nothingInsideACallbackBody() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final x = 1;
      },
      child: Text('hi'),
    );
  }
}
''';
    final messages = await messagesAt(code, 'final x');
    expect(messages.where((m) => m.startsWith('Wrap with')), isEmpty);
  }

  Future<void> test_wrapWithContainerIsSingleLine() async {
    final out = await apply(_screen, "Text('hi')", 'Wrap with Container');
    expect(out, contains("child: Container(child: Text('hi')),"));
  }

  Future<void> test_wrapWithPaddingAddsDefaultInsets() async {
    final out = await apply(_screen, "Text('hi')", 'Wrap with Padding');
    expect(
      out,
      contains(
        "Padding(padding: const EdgeInsets.all(8.0), child: Text('hi'))",
      ),
    );
  }

  Future<void> test_wrapWithColumnIsMultiLineAtTheRightIndent() async {
    final out = await apply(_screen, "Text('hi')", 'Wrap with Column');
    expect(
      out,
      contains('''
    return Center(
      child: Column(
        children: [
          Text('hi'),
        ],
      ),
    );
'''),
    );
  }

  Future<void> test_wrapWithColumnReindentsMultiLineChild() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(
        'hi',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
''';
    final out = await apply(code, "Text(", 'Wrap with Row');
    expect(
      out,
      contains('''
      child: Row(
        children: [
          Text(
            'hi',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
'''),
    );
  }

  Future<void> test_wrapWithBuilder() async {
    final out = await apply(_screen, "Text('hi')", 'Wrap with Builder');
    expect(out, contains("Builder(builder: (context) => Text('hi'))"));
  }

  Future<void> test_wrapWithFutureBuilder() async {
    final out = await apply(_screen, "Text('hi')", 'Wrap with FutureBuilder');
    expect(
      out,
      contains(
        "FutureBuilder(future: future, builder: (context, snapshot) => "
        "Text('hi'))",
      ),
    );
  }

  Future<void> test_wrapWithWidgetUsesAPlaceholderName() async {
    final out = await apply(_screen, "Text('hi')", 'Wrap with widget...');
    expect(out, contains("widget(child: Text('hi'))"));
  }

  static const _constScreen = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('hi'),
    );
  }
}
''';

  Future<void> test_explicitConstStaysOnTheInnerWidget() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: const Text('hi'),
    );
  }
}
''';
    final out = await apply(code, "Text('hi')", 'Wrap with Container');
    expect(out, contains("child: Container(child: const Text('hi')),"));
  }

  Future<void> test_paddingOmitsConstInsideAConstContext() async {
    final out = await apply(_constScreen, "Text('hi')", 'Wrap with Padding');
    expect(
      out,
      contains(
        "child: Padding(padding: EdgeInsets.all(8.0), child: Text('hi')),",
      ),
    );
    expect(out, contains('return const Center('));
  }

  Future<void> test_builderInsideAConstContextDropsTheEnclosingConst() async {
    final out = await apply(_constScreen, "Text('hi')", 'Wrap with Builder');
    expect(out, contains('return Center('));
    expect(
      out,
      contains("child: Builder(builder: (context) => const Text('hi')),"),
    );
  }

  Future<void> test_builderInsideAConstListDropsTheListConst() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: const [Text('a'), Text('b')]);
  }
}
''';
    final out = await apply(code, "Text('a')", 'Wrap with Builder');
    expect(
      out,
      contains(
        "Column(children: [Builder(builder: (context) => const Text('a')), "
        "Text('b')]);",
      ),
    );
  }

  Future<void> test_builderNotOfferedWhenConstCannotBeDropped() async {
    const code = '''
const kLabel = Text('hi');
''';
    final messages = await messagesAt(code, "Text('hi')");
    expect(messages, isNot(contains('Wrap with Builder')));
    expect(messages, contains('Wrap with Container'));
  }

  Future<void> test_multiLineChildIsLaidOutOnItsOwnLines() async {
    const code = '''
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'hi',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
''';
    final out = await apply(code, 'Text(', 'Wrap with Container');
    expect(
      out,
      contains('''
      child: Container(
        child: Text(
          'hi',
          style: TextStyle(fontSize: 12),
        ),
      ),
'''),
    );
  }

  Future<void> test_wrapsAWidgetTypedParameterNotJustCreations() async {
    const code = '''
class Box extends StatelessWidget {
  final Widget child;
  const Box({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}
''';
    final out = await apply(code, 'child);', 'Wrap with Container');
    expect(out, contains('return Center(child: Container(child: child));'));
  }

  Future<void> test_selectionAcrossSiblingsWrapsThemTogether() async {
    const code = '''
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
    final out = await apply(
      code,
      "Text('a')",
      'Wrap with Row',
      through: "Text('b')",
    );
    expect(
      out,
      contains('''
      children: [
        Row(
          children: [
            Text('a'),
            Text('b'),
          ],
        ),
        Text('c'),
      ],
'''),
    );
  }
}
