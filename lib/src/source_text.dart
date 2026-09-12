/// Source-text helpers shared by the assists.
library;

import 'package:analysis_server_plugin/edit/correction_utils.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// A replacement of [length] characters at [offset] with [replacement].
/// Offsets are absolute file offsets.
class TextEdit {
  final int offset;
  final int length;
  final String replacement;

  const TextEdit(this.offset, this.length, this.replacement);

  /// An insertion of [text] at [offset].
  const TextEdit.insert(int offset, String text) : this(offset, 0, text);

  /// A deletion of the range [start, end).
  const TextEdit.delete(int start, int end) : this(start, end - start, '');
}

/// The source of [member] with the indentation of its first line kept, so it
/// can be dropped into another class body as-is.
String memberSource(CorrectionUtils utils, ClassMember member) {
  final indent = utils.getLinePrefix(member.offset);
  return '$indent${utils.getNodeText(member)}';
}

/// Like [memberSource], with [edits] applied. Edits may be given in any
/// order; they must not overlap.
String memberSourceWithEdits(
  CorrectionUtils utils,
  ClassMember member,
  List<TextEdit> edits,
) {
  final source = utils.getNodeText(member);
  final sorted = [...edits]..sort((a, b) => a.offset.compareTo(b.offset));
  final buffer = StringBuffer(utils.getLinePrefix(member.offset));
  var cursor = 0;
  for (final edit in sorted) {
    final local = edit.offset - member.offset;
    buffer
      ..write(source.substring(cursor, local))
      ..write(edit.replacement);
    cursor = local + edit.length;
  }
  buffer.write(source.substring(cursor));
  return buffer.toString();
}

/// Leading whitespace of the line containing [offset].
String lineIndent(String content, int offset) {
  final lineStart = content.lastIndexOf('\n', offset - 1) + 1;
  var end = lineStart;
  while (end < content.length &&
      (content[end] == ' ' || content[end] == '\t')) {
    end++;
  }
  return content.substring(lineStart, end);
}

/// [source] with [extra] prepended to every line after the first, so a
/// multi-line expression can be moved deeper into a tree. Blank lines are
/// left alone.
String reindentContinuationLines(String source, String extra) {
  final lines = source.split('\n');
  return [
    lines.first,
    for (final line in lines.skip(1))
      line.trim().isEmpty ? line : '$extra$line',
  ].join('\n');
}
