import 'package:source_helper/source_helper.dart';
import 'package:sql_serializable/src/generator/config.dart';

/// Generate the fromSql function for a given [config].
String generateFromSql(SqlGeneratorConfig config) {
  final buffer = StringBuffer();

  buffer.writeln('${config.source.name} ${config.fromSqlName}(Sql<${config.source.name}> sql) {');

  if (config.disallowUnrecognizedColumns) {
    buffer.writeln('  for (final column in sql.fields.values) {');
    buffer.writeln('    if (!${config.dartTableName}.columns.keys.contains(column)) {');
    buffer.writeln(
      '     throw UnknownColumnException(${escapeDartString(config.source.name)}, column);',
    );
    buffer.writeln('    }');
    buffer.writeln('  }');
  }

  buffer.writeln('  return ${config.constructorReference}(');

  for (final parameter in config.constructorElement.parameters) {
    final column = config.columnFor(parameter);

    if (column == null) {
      throw Exception(
        'Couldn\'t generate fromJson for ${config.constructorReference} because the parameter'
        ' ${parameter.name} has no matching field',
      );
    }

    if (parameter.isNamed) {
      buffer.write('${column.source.name}: ');
    }

    final fieldRef = 'sql.fields[${escapeDartString(column.columnName)}]';

    if (column.isNullable || column.serializedDefault != null || column.disallowNullValue) {
      buffer.write('($fieldRef != null ? ${column.dartColumnName}.type.fromSql($fieldRef) : null)');
    } else {
      buffer.write('${column.dartColumnName}.type.fromSql($fieldRef)');
    }

    if (column.serializedDefault != null) {
      buffer.write(' ?? ${column.serializedDefault}');
    }

    if (column.disallowNullValue) {
      buffer.write(
          '  ?? (throw DisallowedNullValueException(${config.dartTableName}, ${column.dartColumnName}))');
    }

    buffer.writeln(',');
  }

  buffer.writeln('  );');
  buffer.writeln('}');

  return buffer.toString();
}
