import 'package:source_helper/source_helper.dart';
import 'package:sql_serializable/src/generator/config.dart';

/// Generate the [Column]s and [Table]s for a given [config].
String generateTable(SqlGeneratorConfig config) {
  final buffer = StringBuffer();

  for (final column in config.columns) {
    buffer.writeln('const ${column.dartColumnName} = Column(');
    buffer.writeln('  type: ${column.serializedType},');
    buffer.writeln('  name: ${escapeDartString(column.columnName)},');
    buffer.writeln('  isNullable: ${column.isNullable},');
    buffer.writeln(');');
    buffer.writeln();
  }

  buffer.writeln('const ${config.dartTableName} = Table<${config.source.name}>(');
  buffer.writeln('  name: ${escapeDartString(config.tableName)},');
  buffer.writeln('  toSql: ${config.toSqlName},');
  buffer.writeln('  fromSql: ${config.fromSqlName},');
  buffer.writeln('  columns: [');
  for (final column in config.columns) {
    buffer.writeln('    ${column.dartColumnName},');
  }
  buffer.writeln('  ],');
  buffer.writeln(');');

  return buffer.toString();
}
