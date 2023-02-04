import 'package:collection/collection.dart';
import 'package:sql_serializable/sql_serializable.dart';

/// A database-agnostic representation of an object as SQL rows.
class Sql<T> {
  /// A mapping of column name to value.
  ///
  /// [Sql] values appearing here should be interpreted as references to other tables.
  final Map<String, dynamic> fields;

  /// The table this SQL comes from.
  final Table table;

  const Sql({required this.fields, required this.table});

  @override
  String toString() => 'Sql(${fields.entries.map((e) => '${e.key}: ${e.value}').join(', ')})';
}

/// The configuration for a table in an SQL database.
class Table<T> {
  /// The name of the table.
  ///
  /// WARNING: This field is sometimes passed to SQL queries unescaped. Do not let users control
  /// this field, or you might be exposing your database to an SQL injection attack.
  final String name;

  /// A list of [Column]s in this table.
  final List<Column> columns;

  final Sql<T> Function(T) toSql;

  final T Function(Sql<T>) fromSql;

  const Table({
    required this.name,
    required this.columns,
    required this.toSql,
    required this.fromSql,
  });

  @override
  int get hashCode => Object.hash(name, ListEquality().hash(columns));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Table<T> && name == other.name && ListEquality().equals(columns, other.columns));
}

/// The configuration for a column in an SQL database.
class Column<Dart, Sql> {
  /// The type of this column.
  final SqlType<Dart, Sql> type;

  /// The name of this column.
  ///
  /// WARNING: This field is sometimes passed to SQL queries unescaped. Do not let users control
  /// this field, or you might be exposing your database to an SQL injection attack.
  final String name;

  /// Whether this column is nullable.
  final bool isNullable;

  const Column({
    required this.type,
    required this.name,
    required this.isNullable,
  });

  @override
  int get hashCode => Object.hash(name, type, isNullable);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Column<Dart, Sql> &&
          type == other.type &&
          name == other.name &&
          isNullable == other.isNullable);
}
