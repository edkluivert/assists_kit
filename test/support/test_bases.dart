/// Test bases: [RuleTest] for warning rules, [AssistTest] for assists.
///
/// Both resolve code against the stub `package:dartnative` in
/// `dartnative_stub.dart`, so the suite runs with plain `dart test` and no
/// DartNative SDK.
library;

import 'package:analysis_server_plugin/edit/assist/assist.dart';
import 'package:analysis_server_plugin/edit/assist/dart_assist_context.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/correction/assist_processor.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/correction/dart_change_workspace.dart';
// ignore: implementation_imports
import 'package:analysis_server_plugin/src/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/instrumentation/service.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:dartnative_assists/main.dart';
import 'package:test/test.dart';

import 'dartnative_stub.dart';

const _import = "import 'package:dartnative/dartnative.dart';\n\n";

/// Base for rule tests: the stub package is available and [rule] is set by
/// the subclass. Test code may omit the dartnative import; it is prepended.
abstract class RuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('dartnative').addFile('lib/dartnative.dart', dartnativeStub);
    super.setUp();
  }

  /// Asserts that [code] (without the import line) reports exactly one
  /// diagnostic of the rule under test covering [highlighted].
  Future<void> assertWarning(String code, String highlighted) async {
    final source = _import + code;
    final offset = source.indexOf(highlighted);
    expect(offset, greaterThanOrEqualTo(0), reason: 'highlight not found');
    await assertDiagnostics(source, [lint(offset, highlighted.length)]);
  }

  /// Asserts that [code] (without the import line) reports nothing.
  Future<void> assertClean(String code) => assertNoDiagnostics(_import + code);
}

/// Base for assist tests. Assists are registered once per isolate.
abstract class AssistTest extends AnalysisRuleTest {
  static bool _assistsRegistered = false;

  @override
  void setUp() {
    if (!_assistsRegistered) {
      plugin.registerAssists(PluginRegistryImpl(plugin.name));
      _assistsRegistered = true;
    }
    // The base class insists on a rule under test; assists have none.
    rule = _NoRule();
    newPackage('dartnative').addFile('lib/dartnative.dart', dartnativeStub);
    super.setUp();
  }

  /// All assists offered with the cursor at the first occurrence of
  /// [marker] in [code] (import line prepended).
  Future<List<Assist>> assistsAt(String code, String marker) async {
    final source = _import + code;
    final offset = source.indexOf(marker);
    expect(offset, greaterThanOrEqualTo(0), reason: 'marker not found');
    newFile(testFilePath, source);
    final unit = await resolveFile(testFilePath);
    final library =
        await unit.session.getResolvedLibrary(unit.path)
            as ResolvedLibraryResult;
    final context = DartAssistContext(
      InstrumentationService.NULL_SERVICE,
      DartChangeWorkspace([unit.session]),
      library,
      unit,
      offset,
      0,
    );
    return computeAssists(context);
  }

  /// The messages of the assists offered at [marker].
  Future<List<String>> messagesAt(String code, String marker) async => [
    for (final a in await assistsAt(code, marker)) a.kind.message,
  ];

  /// Applies the assist titled [message] at [marker] and returns the code
  /// after the edit, without the import line.
  Future<String> apply(String code, String marker, String message) async {
    final assists = await assistsAt(code, marker);
    final matches = assists.where((a) => a.kind.message == message).toList();
    expect(matches, hasLength(1), reason: 'assist "$message" not offered');
    var edited = _import + code;
    for (final fileEdit in matches.single.change.edits) {
      edited = SourceEdit.applySequence(edited, fileEdit.edits);
    }
    return edited.substring(_import.length);
  }
}

/// A rule that never reports, to satisfy [AnalysisRuleTest] in assist tests.
class _NoRule extends AnalysisRule {
  static const LintCode code = LintCode('no_rule', 'never reported');

  _NoRule() : super(name: 'no_rule', description: 'Placeholder for tests.');

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {}
}
