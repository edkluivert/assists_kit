/// Runs the plugin's assists against a real file without an IDE.
///
///   `dart run tool/try_assists.dart FILE --find SUBSTRING [--apply N]`
///
/// The cursor is placed at the first occurrence of the substring. Every
/// assist the plugin offers there is listed; with --apply the chosen one is
/// applied and the resulting source is printed.
library;

import 'dart:io';

import 'package:analysis_server_plugin/edit/assist/dart_assist_context.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analysis_server_plugin/src/correction/assist_processor.dart';
import 'package:analysis_server_plugin/src/correction/dart_change_workspace.dart';
import 'package:analysis_server_plugin/src/registry.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/instrumentation/service.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:dartnative_assists/main.dart' as dn;
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: try_assists.dart <file> --find <text> [--apply N]');
    exit(64);
  }
  final file = p.normalize(p.absolute(args[0]));
  String? find;
  int? apply;
  for (var i = 1; i < args.length; i++) {
    if (args[i] == '--find') find = args[++i];
    if (args[i] == '--apply') apply = int.parse(args[++i]);
  }
  final content = File(file).readAsStringSync();
  final offset = find == null ? 0 : content.indexOf(find);
  if (offset < 0) {
    stderr.writeln('substring not found: $find');
    exit(1);
  }

  final PluginRegistry registry = PluginRegistryImpl(dn.plugin.name);
  dn.plugin.register(registry);

  final collection = AnalysisContextCollection(
    includedPaths: [p.dirname(file)],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final session = collection.contextFor(file).currentSession;
  final unit = await session.getResolvedUnit(file);
  if (unit is! ResolvedUnitResult) {
    stderr.writeln('could not resolve $file: $unit');
    exit(1);
  }
  final library = await session.getResolvedLibrary(file);
  if (library is! ResolvedLibraryResult) {
    stderr.writeln('could not resolve library: $library');
    exit(1);
  }

  final context = DartAssistContext(
    InstrumentationService.NULL_SERVICE,
    DartChangeWorkspace([session]),
    library,
    unit,
    offset,
    0,
  );
  final assists = await computeAssists(context);
  final line = unit.lineInfo.getLocation(offset);
  stdout.writeln('${assists.length} assist(s) at $line:');
  for (var i = 0; i < assists.length; i++) {
    stdout.writeln('  [$i] ${assists[i].kind.message}');
  }
  if (apply != null && apply < assists.length) {
    final change = assists[apply].change;
    var result = content;
    for (final fileEdit in change.edits) {
      result = SourceEdit.applySequence(result, fileEdit.edits);
    }
    stdout.writeln('--- after "${assists[apply].kind.message}" ---');
    stdout.write(result);
  }
}
