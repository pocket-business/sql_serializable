import 'package:source_helper/source_helper.dart';
import 'package:sql_serializable/src/generator/config.dart';

/// Generate the field map for a given [config].
String generateFieldMap(SqlGeneratorConfig config) {
  final buffer = StringBuffer();

  buffer.writeln('const ${config.fieldMapName} = <String, String>{');
  for (final column in config.columns) {
    buffer.writeln(
      '  ${escapeDartString(column.source.name)}: ${escapeDartString(column.dartColumnName)},',
    );
  }
  buffer.writeln('};');

  return buffer.toString();
}
