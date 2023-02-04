import 'package:sql_serializable/sql_serializable.dart';

/// An error thrown when an unexpected column appears when decoding an [Sql].
class UnknownColumnException implements Exception {
  /// The name of the unexpected column.
  final String columnName;

  /// The name of the class the column appeared in.
  final String className;

  const UnknownColumnException(this.className, this.columnName);

  @override
  String toString() => 'Unknown column $columnName in Sql when parsing $className';
}

/// An error thrown when `null` appears in a column that has [SqlColumn.disallowNullValue].
class DisallowedNullValueException implements Exception {
  /// The column the value appeared in.
  final Column column;

  /// The table the column appeared in.
  final Table table;

  const DisallowedNullValueException(this.table, this.column);

  @override
  String toString() => 'Disallowed null value in column ${column.name} when parsing ${table.name}';
}

/// An error thrown when a type was unable to be converted to SQL.
class ConversionNotSupportedException implements Exception {
  final String message;

  const ConversionNotSupportedException(this.message);

  @override
  String toString() => message;
}

/// An error thrown when [id] does not exist in [table].
class DoesNotExistException {
  /// The id that did not exist.
  final int id;

  /// The table in which the item was requested.
  final Table table;

  const DoesNotExistException(this.table, this.id);

  @override
  String toString() => 'Row with id $id does not exist in table ${table.name}';
}
