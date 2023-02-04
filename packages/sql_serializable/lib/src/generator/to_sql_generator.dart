import 'package:source_helper/source_helper.dart';
import 'package:sql_serializable/src/generator/config.dart';

/// Generate the `toSql` function for a given [config].
String generateToSql(SqlGeneratorConfig config) {
  final buffer = StringBuffer();

  buffer.writeln(
      'Sql<${config.source.name}> ${config.toSqlName}(${config.source.name} instance) => Sql(');
  buffer.writeln('  table: ${config.dartTableName},');
  buffer.writeln('  fields: {');
  for (final column in config.columns) {
    final fieldRef = 'instance.${column.source.name}';

    buffer.write('    ${escapeDartString(column.columnName)}: ');

    if (column.isNullable) {
      buffer.writeln(
        '$fieldRef != null ? ${column.dartColumnName}.type.toSql($fieldRef!): null,',
      );
    } else {
      buffer.writeln('${column.dartColumnName}.type.toSql($fieldRef),');
    }
  }
  buffer.writeln('  },');
  buffer.writeln(');');

  return buffer.toString();
}
