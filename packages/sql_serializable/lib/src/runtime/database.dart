import 'dart:async';

import 'package:sql_serializable/sql_serializable.dart';

/// A database that supports querying [Sql] objects from `sql_serializable`.
abstract class SqlSerializableDatabase {
  /// An [SqlMigrations] instance responsible for running migrations for this database.
  SqlMigrations<SqlSerializableDatabase> get migrations;

  /// Insert [Sql] into this database, returning its ID.
  FutureOr<int> insert<T>(Sql<T> sql);

  /// Query [table] and return a mapping of ID to [Sql].
  ///
  /// Returns at most [limit] items. If [page] is specified, skips over [limit] * [page] items
  /// before returning any items.
  FutureOr<Map<int, Sql<T>>> list<T>(Table<T> table, {int? limit, int? page});

  /// Get a single item from [table] by its [id].
  ///
  /// Throws [DoesNotExistException] if [id] does not exist in [table].
  FutureOr<Sql<T>> get<T>(Table<T> table, int id);

  /// Delete an item from [table] by its [id].
  ///
  /// Also deletes any related items in other tables referenced by [table] (but does not delete
  /// items that reference [table]).
  FutureOr<void> delete(Table table, int id);

  /// Update the item with [id] with the contents of [sql].
  FutureOr<void> update<T>(int id, Sql<T> sql);

  /// Perform [callback] in a transaction.
  ///
  /// Writes made during a transaction will not be committed unless the entire transaction
  /// completes. [callback] is considered to be a successful callback if it returns without
  /// throwing.
  FutureOr<T> transaction<T>(FutureOr<T> Function() callback);

  /// Perform [query] on this database and parse the value as an [Sql] from [table].
  ///
  /// Values in [substitutions] will be substituted into the query. The format of these
  /// substitutions depends on the underlying database package.
  ///
  /// Each row in the query must contain every column in [table] with the correct data type.
  ///
  /// Returns a mapping of id to value.
  FutureOr<Map<int, Sql<T>>> query<T>(Table<T> table, String query,
      {Map<String, dynamic>? substitutions});
}

/// A set of operations called during an implicit migration.
abstract class SqlMigrations<T extends SqlSerializableDatabase> {
  /// The database being migrated.
  T get database;

  /// Ensure that [table] exists in the database with the correct schema.
  FutureOr<void> ensureReady(Table table);

  /// Add [table] to [database].
  FutureOr<void> addTable(Table table);

  /// Add [column] to [table].
  FutureOr<void> addColumn(Table table, Column column);

  /// Update [column] in [table] following a configuration change.
  FutureOr<void> updateColumn(Table table, Column column);

  /// Remove [column] from [table].
  FutureOr<void> removeColumn(Table table, String column);
}
