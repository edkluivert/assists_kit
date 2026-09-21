// ignore_for_file: non_constant_identifier_names

import 'package:assists_kit/src/rules/rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/flutterbloc_stub.dart';
import '../support/test_bases.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FlutterblocWatchOutsideBuildTest);
    defineReflectiveTests(FlutterblocReadStateInBuildTest);
    defineReflectiveTests(FlutterblocReadInBuildTest);
  });
}

const _blocImport = "import 'package:flutterbloc_kit/flutterbloc_kit.dart';\n";

const _cubit = '''
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

class Button extends Widget {
  final void Function()? onPressed;
  const Button({super.key, this.onPressed});
}
''';

abstract class BlocRuleTest extends RuleTest {
  @override
  void setUp() {
    // Before super.setUp(), which writes the package config.
    newPackage('flutterbloc_kit').addFile(
      'lib/flutterbloc_kit.dart',
      flutterblocStub,
    );
    super.setUp();
  }

  Future<void> assertBlocWarning(String code, String highlighted) =>
      assertWarning(_blocImport + _cubit + code, highlighted);

  Future<void> assertBlocClean(String code) =>
      assertClean(_blocImport + _cubit + code);
}

@reflectiveTest
class FlutterblocWatchOutsideBuildTest extends BlocRuleTest {
  @override
  void setUp() {
    rule = FlutterblocWatchOutsideBuild();
    super.setUp();
  }

  Future<void> test_reportsWatchInAHandler() => assertBlocWarning('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) => Button(
    onPressed: () => context.watch<CounterCubit>().increment(),
  );
}
''', 'watch');

  Future<void> test_reportsSelectInInitState() => assertBlocWarning('''
class Page extends StatefulWidget {
  const Page({super.key});
  @override
  State<Page> createState() => _PageState();
}

class _PageState extends State<Page> {
  int? count;
  @override
  void initState() {
    super.initState();
    count = context.select<CounterCubit, int>((c) => c.state);
  }
  @override
  Widget build(BuildContext context) => Text('\$count');
}
''', 'select');

  Future<void> test_quietInBuild() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context.watch<CounterCubit>().state;
    return Text('\$count');
  }
}
''');

  Future<void> test_quietInABuilderCallback() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<CounterCubit, int>(
    builder: (context, state) {
      final even = context.select<CounterCubit, bool>((c) => c.state.isEven);
      return Text('\$even');
    },
  );
}
''');

  Future<void> test_quietForReadInAHandler() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) => Button(
    onPressed: () => context.read<CounterCubit>().increment(),
  );
}
''');
}

@reflectiveTest
class FlutterblocReadStateInBuildTest extends BlocRuleTest {
  @override
  void setUp() {
    rule = FlutterblocReadStateInBuild();
    super.setUp();
  }

  Future<void> test_reportsReadStateInBuild() => assertBlocWarning('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context.read<CounterCubit>().state;
    return Text('\$count');
  }
}
''', 'context.read<CounterCubit>().state');

  Future<void> test_reportsInABuilderCallback() => assertBlocWarning('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<CounterCubit, int>(
    builder: (context, state) => Text('\${context.read<CounterCubit>().state}'),
  );
}
''', 'context.read<CounterCubit>().state');

  Future<void> test_quietInAHandler() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) => Button(
    onPressed: () {
      if (context.read<CounterCubit>().state < 10) {
        context.read<CounterCubit>().increment();
      }
    },
  );
}
''');

  Future<void> test_quietForReadWithoutState() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CounterCubit>();
    return Button(onPressed: cubit.increment);
  }
}
''');

  Future<void> test_quietForWatchState() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) =>
      Text('\${context.watch<CounterCubit>().state}');
}
''');
}

@reflectiveTest
class FlutterblocReadInBuildTest extends BlocRuleTest {
  @override
  void setUp() {
    rule = FlutterblocReadInBuild();
    super.setUp();
  }

  Future<void> test_reportsReadInBuild() => assertBlocWarning('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CounterCubit>();
    return Button(onPressed: cubit.increment);
  }
}
''', 'read');

  Future<void> test_quietInAHandler() => assertBlocClean('''
class Page extends StatelessWidget {
  const Page({super.key});
  @override
  Widget build(BuildContext context) => Button(
    onPressed: () => context.read<CounterCubit>().increment(),
  );
}
''');
}
