import 'package:meta/meta_meta.dart';
import 'package:sql_serializable/sql_serializable.dart';

/// Annotate a class with [SqlSerializable] to generate functions to encode/decode it to/from [Sql].
@Target({TargetKind.classType})
class SqlSerializable {
  /// The name of the table for this type in the SQL database.
  final String? tableName;

  /// The constructor in this class to generate the functions for.
  ///
  /// This is the constructor called by the generated `fromJson` function. It must be callable with
  /// a single positional argument of type [Sql]<T>.
  final String constructor;

  /// Whether to create a mapping of field name to [Column] objects.
  final bool createFieldMap;

  /// Whether to throw an error if the database returns an unknown column.
  final bool disallowUnrecognizedColumns;

  /// The method to use when generating column names for fields.
  final FieldRename fieldRename;

  const SqlSerializable({
    this.tableName,
    this.constructor = '',
    this.createFieldMap = false,
    this.disallowUnrecognizedColumns = false,
    this.fieldRename = FieldRename.snake,
  });
}

/// Different methods used to rename fields for their SQL column names.
enum FieldRename {
  /// Do not apply any changes to the field name in the column name.
  none,

  /// Convert the field name to kebab-case in the column name.
  kebab,

  /// Convert the field name to snake_case in the column name.
  snake,

  /// Convert the field name to PascalCase in the column name.
  pascal,

  /// Convert the field name to SCREAMING_SNAKE_CASE in the column name.
  screamingSnake,
}

/// Annotate fields in a class annotated with [SqlSerializable] with this annotation to configure
/// the generated SQL column.
@Target({TargetKind.field, TargetKind.getter})
class SqlColumn<T> {
  /// The name of this column.
  final String? columnName;

  /// The default value for this column if a null value is encountered.
  final Object? defaultValue;

  /// Whether to throw an error if a null value appears in this column.
  final bool disallowNullValue;

  const SqlColumn({
    this.columnName,
    this.defaultValue,
    this.disallowNullValue = false,
  });
}
