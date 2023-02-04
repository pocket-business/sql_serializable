import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'package:sql_serializable/sql_serializable.dart';
import 'package:sql_serializable/src/generator/config.dart';
import 'package:sql_serializable/src/generator/field_map_generator.dart';
import 'package:sql_serializable/src/generator/from_sql_generator.dart';
import 'package:sql_serializable/src/generator/table_generator.dart';
import 'package:sql_serializable/src/generator/to_sql_generator.dart';

/// The generator for `sql_serializable`.
class SqlSerializableGenerator extends GeneratorForAnnotation<SqlSerializable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw Exception('Invalid annotation target: ${element.kind.displayName}');
    }

    final config = SqlGeneratorConfig(element, annotation);

    final buffer = StringBuffer();

    buffer.writeln(generateTable(config));
    buffer.writeln(generateToSql(config));
    buffer.writeln(generateFromSql(config));

    if (config.createFieldMap) {
      buffer.writeln(generateFieldMap(config));
    }

    return buffer.toString();
  }
}
