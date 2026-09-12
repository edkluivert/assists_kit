// ignore_for_file: non_constant_identifier_names

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/test_bases.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ConvertToStatefulTest);
    defineReflectiveTests(ConvertToStatelessTest);
  });
}

@reflectiveTest
class ConvertToStatefulTest extends AssistTest {
  static const _stateless = '''
class Greeting extends StatelessWidget {
  static const int kMax = 3;
  final String name;
  final int count;
  const Greeting({super.key, required this.name, this.count = 0});

  String get label => '\$name (\$count of \$kMax)';

  bool get isFull => count >= kMax;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: TextStyle(fontSize: isFull ? 24 : 20));
  }
}
''';

  Future<void> test_offeredOnTheClassHeaderOnly() async {
    expect(
      await messagesAt(_stateless, 'class Greeting'),
      contains('Convert to StatefulWidget'),
    );
    expect(
      await messagesAt(_stateless, 'Text(label'),
      isNot(contains('Convert to StatefulWidget')),
    );
  }

  Future<void> test_splitsWidgetAndState() async {
    final out = await apply(
      _stateless,
      'class Greeting',
      'Convert to StatefulWidget',
    );
    expect(
      out,
      contains('''
class Greeting extends StatefulWidget {
  static const int kMax = 3;

  final String name;

  final int count;

  const Greeting({super.key, required this.name, this.count = 0});

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
'''),
    );
  }

  Future<void> test_rewritesFieldStaticAndInterpolationReferences() async {
    final out = await apply(
      _stateless,
      'class Greeting',
      'Convert to StatefulWidget',
    );
    expect(
      out,
      contains(
        r"String get label => '${widget.name} (${widget.count} of "
        r"${Greeting.kMax})';",
      ),
    );
    expect(out, contains('bool get isFull => widget.count >= Greeting.kMax;'));
  }

  Future<void> test_movedGetterIsNotPrefixed() async {
    final out = await apply(
      _stateless,
      'class Greeting',
      'Convert to StatefulWidget',
    );
    expect(out, contains('return Text(label, style:'));
  }

  Future<void> test_keepsTypeParameters() async {
    const code = '''
class Box<T> extends StatelessWidget {
  final T value;
  const Box({super.key, required this.value});

  @override
  Widget build(BuildContext context) => Text('\$value');
}
''';
    final out = await apply(code, 'class Box', 'Convert to StatefulWidget');
    expect(out, contains('State<Box<T>> createState() => _BoxState<T>();'));
    expect(out, contains('class _BoxState<T> extends State<Box<T>> {'));
  }
}

@reflectiveTest
class ConvertToStatelessTest extends AssistTest {
  static const _stateful = '''
class Plain extends StatefulWidget {
  final String title;
  const Plain({super.key, required this.title});

  @override
  State<Plain> createState() => _PlainState();
}

class _PlainState extends State<Plain> {
  @override
  Widget build(BuildContext context) {
    return Text(widget.title);
  }
}
''';

  Future<void> test_mergesStateBackAndStripsWidgetQualifier() async {
    final out = await apply(
      _stateful,
      'class Plain',
      'Convert to StatelessWidget',
    );
    expect(
      out,
      contains('''
class Plain extends StatelessWidget {
  final String title;

  const Plain({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title);
  }
}
'''),
    );
    expect(out, isNot(contains('_PlainState')));
  }

  Future<void> test_refusedWhenStateCallsSetState() async {
    const code = '''
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => n++),
      child: Text('\$n'),
    );
  }
}
''';
    expect(
      await messagesAt(code, 'class Counter'),
      isNot(contains('Convert to StatelessWidget')),
    );
  }

  Future<void> test_refusedWhenStateOverridesLifecycle() async {
    const code = '''
class Loader extends StatefulWidget {
  const Loader({super.key});

  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Text('x');
}
''';
    expect(
      await messagesAt(code, 'class Loader'),
      isNot(contains('Convert to StatelessWidget')),
    );
  }
}
