import 'dart:async';

import 'package:postgres/postgres.dart' as pg;
import 'package:sql_serializable_postgres/sql_serializable_postgres.dart';
import 'package:sql_serializable_postgres/src/types.dart';

/// An [SqlSerializableDatabase] interface over a PostgreSQL database.
class PostgresDatabase extends SqlSerializableDatabase {
  /// The connection this database is using.
  final pg.Connection connection;

  /// The current execution context.
  ///
  /// Prefer accessing this over [connection] as it will correctly
  /// return the transaction context if in a transaction.
  pg.Session get context => Zone.current[#_context] ?? connection;

  @override
  late final PostgresDatabaseMigrations migrations;

  /// Create a new [PostgresDatabase] from a [PostgreSQLConnection].
  ///
  /// The [connection] must be opened before using this database.
  PostgresDatabase(
    this.connection, {
    PostgresDatabaseMigrations? migrations,
  }) {
    this.migrations = migrations ?? PostgresDatabaseMigrations(this);
  }

  @override
  Future<Map<int, Sql<T>>> query<T>(
    Table<T> table,
    String query, {
    Map<String, dynamic>? substitutions,
  }) async {
    await migrations.ensureReady(table);

    final result = await context.execute(query, parameters: substitutions);

    return {
      for (final row in result)
        row.toColumnMap()['id'] as int: await row.toSql(table, this),
    };
  }

  @override
  Future<Map<int, Sql<T>>> list<T>(Table<T> table,
      {int? limit, int? page}) async {
    return await query(
      table,
      'SELECT * FROM "${table.name}" LIMIT @limit OFFSET @offset;',
      substitutions: {
        'limit': limit,
        'offset': (page != null && limit != null) ? page * limit : null,
      },
    );
  }

  @override
  Future<Sql<T>> get<T>(Table<T> table, int id) async {
    final result = await query(
      table,
      'SELECT * FROM "${table.name}" WHERE id = @id;',
      substitutions: {
        'id': id,
      },
    );

    if (result.isEmpty) {
      throw DoesNotExistException(table, id);
    }

    return result.values.single;
  }

  @override
  Future<void> delete(Table table, int id) async {
    await transaction(() async {
      for (final column in table.columns) {
        switch (column.type) {
          case SimpleType():
          case EnumType():
          case ReferenceType():
            break;
          case ListType():
          case SetType():
          case MapType():
            final storageTable =
                (column.type as KeyedCollectionType).storageTableFor(table);

            await query(
              storageTable,
              'DELETE FROM "${storageTable.name}" WHERE owner = @id',
              substitutions: {
                'id': id,
              },
            );
        }
      }

      final result = (await query(
        table,
        'DELETE FROM "${table.name}" WHERE id = @id RETURNING *;',
        substitutions: {'id': id},
      ))
          .values
          .single;

      // Cascade deletion to other tables
      for (final column in table.columns) {
        switch (column.type) {
          case SimpleType():
          case EnumType():
          case ListType():
          case SetType():
          case MapType():
            break;
          case ReferenceType(table: final referencedTable):
            final referencedId = result.fields[column.name] as int?;

            if (referencedId == null) {
              break;
            }

            await delete(referencedTable, referencedId);
        }
      }
    });
  }

  @override
  Future<int> insert<T>(Sql<T> sql) async {
    await migrations.ensureReady(sql.table);

    return await transaction(() async {
      final columns = [];
      final values = [];
      final substitutions = <String, dynamic>{};

      int counter = 0;

      for (final column in sql.table.columns) {
        final columnVariable = 'col_${counter++}';

        if (column.type.hasColumn) {
          final value = sql.fields[column.name];

          columns.add('"${column.name}"');
          values.add('@$columnVariable');

          if (value == null) {
            substitutions[columnVariable] = null;
          } else {
            substitutions[columnVariable] =
                await column.type.encode(value, this);
          }
        } else {
          final value = sql.fields[column.name];

          columns.add('"${column.nullMarkerName}"');
          values.add('@$columnVariable');

          substitutions[columnVariable] = value == null;
        }
      }

      final result = await context.execute(
        'INSERT INTO "${sql.table.name}" (${columns.join(', ')}) VALUES (${values.join(', ')}) RETURNING id',
        parameters: substitutions,
      );

      final id = result.single.single as int;

      for (final externalColumn
          in sql.table.columns.where((column) => !column.type.hasColumn)) {
        final value = sql.fields[externalColumn.name];

        if (value == null) {
          continue;
        }

        await externalColumn.type.put(value, id, sql.table, this);
      }

      return id;
    });
  }

  @override
  Future<void> update<T>(int id, Sql<T> sql) async {
    await transaction(() async {
      await delete(sql.table, id);

      final newId = await insert(sql);

      return await context.execute(
        'UPDATE "${sql.table.name}" SET id = @oldId WHERE id = @newId;',
        parameters: {
          'newId': newId,
          'oldId': id,
        },
      );
    });
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function() callback) async {
    if (Zone.current[#_transaction] == true) {
      return await callback();
    }

    late final T returnValue;

    await connection.runTx((connection) async {
      returnValue = await runZoned(callback, zoneValues: {
        #_context: connection,
        #_transaction: true,
      });
    });

    return returnValue;
  }
}
