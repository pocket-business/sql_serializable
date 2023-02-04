import 'package:analyzer/dart/element/element.dart';
import 'package:grammer/grammer.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';
import 'package:sql_serializable/sql_serializable.dart';
import 'package:sql_serializable/src/generator/generator_type_mapping.dart';

/// The configuration needed to generate the output for a single class annotated with
/// [SqlSerializable].
///
/// All fields on [SqlSerializable] are also implemented here, instead of being read from
/// [annotation] at each call site.
class SqlGeneratorConfig implements SqlSerializable {
  /// The element the output is being generated for.
  final ClassElement source;

  /// A [ConstantReader] of the [SqlSerializable] annotation this configuration represents.
  final ConstantReader annotation;

  SqlGeneratorConfig(this.source, this.annotation);

  @override
  String get tableName => annotation.read('tableName').isNull
      ? Grammer(source.name.snake).toPlural().first
      : annotation.read('tableName').stringValue;

  @override
  String get constructor => annotation.read('constructor').stringValue;

  @override
  bool get createFieldMap => annotation.read('createFieldMap').boolValue;

  @override
  bool get disallowUnrecognizedColumns =>
      annotation.read('disallowUnrecognizedColumns').boolValue;

  @override
  FieldRename get fieldRename =>
      FieldRename.values[annotation.read('fieldRename').read('index').intValue];

  /// A serialized reference to the constructor called.
  ///
  /// If [constructor] is empty, this returns `Source`. Otherwise, returns `Source.constructor`.
  String get constructorReference {
    if (constructor.isEmpty) {
      return source.name;
    }

    return '${source.name}.$constructor';
  }

  /// The element that represents the constructor in the element tree.
  ExecutableElement get constructorElement {
    return source.constructors
        .cast<ExecutableElement>()
        .followedBy(source.methods.where((element) => element.isStatic))
        .firstWhere(
          (element) => element.name == constructor,
          orElse: () => throw Exception(
            constructor.isEmpty
                ? 'Bad configuration: ${source.name} must have an unnamed constructor'
                : 'Bad configuration: ${source.name} must have a constructor or static method named'
                    ' $constructor',
          ),
        );
  }

  /// A prefix for all generated symbols.
  String get prefix => r'_$';

  /// The name of the Dart [Table] used to represent this element.
  String get dartTableName => '$prefix${source.name}Table';

  /// The name of the function to generate to perform the `type` => [Sql] conversion.
  String get toSqlName => '$prefix${source.name}ToSql';

  /// The name of the function to generate to perform the [Sql] => `type` conversion.
  String get fromSqlName => '$prefix${source.name}FromSql';

  /// The name of the field map to generate for this type.
  String get fieldMapName => '$prefix${source.name}Meta';

  /// The [SqlColumnConfig]s that represent the columns in this type.
  Iterable<SqlColumnConfig> get columns sync* {
    for (final field in source.fields) {
      if (!field.isStatic) {
        yield SqlColumnConfig(this, field);
      }
    }
  }

  /// Returns the column associated with [element], or `null` if none is found.
  SqlColumnConfig? columnFor(ParameterElement element) {
    for (final column in columns) {
      if (column.source.name == element.name) {
        return column;
      }
    }

    return null;
  }
}

/// The configuration needed to generate the [Column] for a given field in a class annotated with
/// [SqlSerializable].
class SqlColumnConfig {
  /// The element this column represents.
  final FieldElement source;

  /// The [SqlGeneratorConfig] of the class this element belongs to.
  final SqlGeneratorConfig config;

  /// A [ConstantReader] of the [SqlColumn] annotation on this field, or `null` if no such
  /// annotation is present.
  late final ConstantReader? annotation;

  SqlColumnConfig(this.config, this.source) {
    final annotationElement =
        TypeChecker.fromRuntime(SqlColumn).firstAnnotationOf(source);

    if (annotationElement != null) {
      annotation = ConstantReader(annotationElement);
    } else {
      annotation = null;
    }
  }

  /// Whether this column should throw an error when deserializing a `null` value.
  bool get disallowNullValue =>
      annotation?.read('disallowNullValue').boolValue ?? false;

  /// A serialized reference to the [SqlColumn.defaultValue], if any.
  String? get serializedDefault {
    try {
      return annotation?.read('defaultValue').revive().toString();
    } on StateError {
      // Value is a literal
      return annotation!.read('defaultValue').literalValue.toString();
    } on UnsupportedError {
      // Value is null (no default)
      return null;
    }
  }

  /// Whether this column is nullable.
  bool get isNullable => source.type.isNullableType;

  /// The name of this column to use in the SQL database.
  String get columnName {
    if (annotation?.read('columnName').isNull == false) {
      return annotation!.read('columnName').stringValue;
    }

    return switch (config.fieldRename) {
      FieldRename.none =>  source.name,
      FieldRename.kebab =>  source.name.kebab,
      FieldRename.snake =>  source.name.snake,
      FieldRename.pascal =>  source.name.pascal,
      FieldRename.screamingSnake =>  source.name.snake.toUpperCase(),
    };
  }

  /// The name of the Dart [Column] instance to represent this column.
  String get dartColumnName =>
      '${config.prefix}${config.source.name}\$${source.name}';

  /// A serialized [SqlType] representing the type of this column.
  String get serializedType => serializedConverterFor(
        name: columnName,
        type: source.type,
        library: source.library,
      );
}
