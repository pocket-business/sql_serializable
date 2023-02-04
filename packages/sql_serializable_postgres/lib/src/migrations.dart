import 'package:collection/collection.dart';
import 'package:postgres/postgres.dart';
import 'package:sql_serializable/sql_serializable.dart';
import 'package:sql_serializable_postgres/src/database.dart';
import 'package:sql_serializable_postgres/src/types.dart';

/// A migrations handler for a [PostgresDatabase].
class PostgresDatabaseMigrations extends SqlMigrations<PostgresDatabase> {
  @override
  final PostgresDatabase database;

  PostgresDatabaseMigrations(this.database);

  final Set<Table> _preparedTables = {};

  @override
  Future<void> ensureReady(Table table) async {
    if (!_preparedTables.add(table)) {
      // Already processed
      return;
    }

    for (final column in table.columns) {
      final dependency = column.type.getDependencies();
      if (dependency != null) {
        await ensureReady(dependency);
      }
    }

    final tableInfo = (await _getExistingTables(table.name)).map((row) => row.toColumnMap());

    if (tableInfo.isEmpty) {
      await addTable(table);
    } else {
      final databaseColumns = (await _getColumns(table.name)).map((row) => row.toColumnMap());

      for (var localColumn in table.columns) {
        if (!localColumn.type.hasColumn) {
          localColumn = Column(
            type: SimpleType.boolean,
            name: localColumn.nullMarkerName,
            isNullable: false,
          );
        }

        final databaseColumn = databaseColumns.firstWhereOrNull(
          (row) => row['column_name'] == localColumn.name,
        );

        if (databaseColumn == null) {
          await addColumn(table, localColumn);
          continue;
        }

        final needsUpdate = databaseColumn['data_type'] != localColumn.type.postgresType ||
            databaseColumn['is_nullable'] != (localColumn.isNullable ? 'YES' : 'NO') ||
            (await _getReference(table.name, localColumn.name)) != localColumn.type.referencedTable;

        if (needsUpdate) {
          await updateColumn(table, localColumn);
        }
      }

      final databaseColumnNames = databaseColumns.map((row) => row['column_name']);
      final localColumnNames = table.columns.map(
        (column) => column.type.hasColumn ? column.name : column.nullMarkerName,
      );

      for (final columnName in databaseColumnNames.toSet().difference(localColumnNames.toSet())) {
        if (columnName == 'id') {
          continue;
        }

        await removeColumn(table, columnName);
      }
    }

    for (final column in table.columns) {
      final dependant = column.type.getDependants(table);

      if (dependant != null) {
        await ensureReady(dependant);
      }
    }
  }

  @override
  Future<void> addTable(Table table) async {
    final columns = [
      'id serial PRIMARY KEY NOT NULL',
      ...table.columns.where((column) => column.type.hasColumn).map(columnDefinition),
      ...table.columns
          .where((column) => !column.type.hasColumn)
          .map((column) => Column(
                type: SimpleType.boolean,
                name: column.nullMarkerName,
                isNullable: false,
              ))
          .map(columnDefinition),
    ];

    await database.context.query(
      'CREATE TABLE ${table.name} (${columns.join(', ')});',
    );
  }

  @override
  Future<void> addColumn(Table table, Column column) async {
    await database.context.query(
      'ALTER TABLE "${table.name}" ADD COLUMN ${columnDefinition(column)};',
    );
  }

  @override
  Future<void> removeColumn(Table table, String column) async {
    await database.context.query(
      'ALTER TABLE "${table.name}" DROP COLUMN "$column";',
    );
  }

  @override
  Future<void> updateColumn(Table table, Column column) async {
    assert(
      column.type.hasColumn,
      'Attempted to update the column for a type without a column',
    );

    final alterations = [
      'TYPE ${column.type.postgresType}',
      '${column.isNullable ? 'DROP' : 'SET'} NOT NULL',
      // TODO: Update references
    ];

    final alterationsList =
        alterations.map((alteration) => 'ALTER COLUMN "${column.name}" $alteration').join(', ');

    await database.context.query(
      'ALTER TABLE "${table.name}" $alterationsList;',
    );
  }

  /// Generate the column definition for [column].
  String columnDefinition(Column column) {
    assert(
      column.type.hasColumn,
      'Attempted to create column definition for a type without a column',
    );

    final ret = StringBuffer();

    ret.write(column.name);
    ret.write(' ${column.type.postgresType}');

    if (!column.isNullable) {
      ret.write(' NOT NULL');
    }

    final referencedTable = column.type.referencedTable;
    if (referencedTable != null) {
      ret.write(' REFERENCES "$referencedTable" (id) ON UPDATE CASCADE');
    }

    return ret.toString();
  }

  Future<PostgreSQLResult> _getExistingTables(String tableName) {
    return database.context.query(
      'SELECT tablename FROM pg_catalog.pg_tables WHERE tablename = @table;',
      substitutionValues: {
        'table': tableName,
      },
    );
  }

  Future<PostgreSQLResult> _getColumns(String tableName) {
    return database.context.query(
      '''
        SELECT
          col.column_name,
          col.data_type,
          col.is_nullable
        FROM
          information_schema.columns col
        WHERE
          col.table_name = @table;
      ''',
      substitutionValues: {
        'table': tableName,
      },
    );
  }

  Future<String?> _getReference(String tableName, String columnName) async {
    final referencedTable = await database.context.query(
      '''
        select
          (select r.relname from pg_class r where r.oid = c.conrelid) as table,
          (select array_agg(attname) from pg_attribute
            where attrelid = c.conrelid and ARRAY[attnum] <@ c.conkey) as col,
          (select r.relname from pg_class r where r.oid = c.confrelid) as ftable
        from pg_constraint c
        where
          c.conrelid = (select oid from pg_class where relname = @table)
          and c.conkey @> (select array_agg(attnum) from pg_attribute
            where attname = @column and attrelid = c.conrelid);
      ''',
      substitutionValues: {
        'table': tableName,
        'column': columnName,
      },
    );

    return referencedTable.singleOrNull?.toColumnMap()['ftable'];
  }
}
