import 'package:postgres/postgres.dart';
import 'package:sql_serializable/sql_serializable.dart';
import 'package:sql_serializable_postgres/src/database.dart';
import 'package:sql_serializable_postgres/src/types.dart';

/// Utilities for converting [PostgreSQLResult]s to [Sql].
extension MultipleResults on PostgreSQLResult {
  /// Convert this [PostgreSQLResult] to a list of [Sql] from [table].
  ///
  /// Each row in this result must contain every contain every column in [table] with the correct
  /// data type.
  Future<List<Sql<T>>> toSql<T>(Table<T> table, PostgresDatabase database) =>
      Future.wait(map((row) => row.toSql(table, database)));
}

/// Utilities for converting [PostgreSQLResultRow]s to [Sql].
extension SingleResult on PostgreSQLResultRow {
  /// Convert this [PostgreSQLResultRow] to an [Sql] from [table].
  ///
  /// This row must contain every column in [table] with the correct data type, as well as the
  /// automatically generated `id` column.
  Future<Sql<T>> toSql<T>(Table<T> table, PostgresDatabase database) async {
    final row = toColumnMap();

    final fields = <String, dynamic>{};

    for (final column in table.columns) {
      if (column.type.hasColumn) {
        final sql = row[column.name];

        if (sql == null) {
          fields[column.name] = null;
        } else {
          fields[column.name] = await column.type.decode(sql, database);
        }
      } else {
        final isNull = row[column.nullMarkerName] as bool;

        if (isNull) {
          fields[column.name] = null;
        } else {
          fields[column.name] = await column.type.fetch(row['id'] as int, table, database);
        }
      }
    }

    return Sql<Never>(table: table, fields: fields);
  }
}
