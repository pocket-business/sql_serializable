import 'package:collection/collection.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:sql_serializable_postgres/sql_serializable_postgres.dart';

extension PostgresType on SqlType {
  bool get hasColumn => switch (this) {
        SimpleType() || EnumType() || ReferenceType() => true,
        ListType() || SetType() || MapType() => false,
      };

  String? get postgresType => switch (this) {
        SimpleType() => switch (this as SimpleType) {
            SimpleType.bigInt => 'bigint',
            SimpleType.boolean => 'boolean',
            SimpleType.dateTime => 'timestamp',
            SimpleType.double_ => 'double precision',
            SimpleType.duration => 'interval',
            SimpleType.integer =>
              'bigint', // Dart's 64 bit integers won't fit in an int4
            SimpleType.number => 'decimal',
            SimpleType.regExp => 'text',
            SimpleType.string => 'text',
            SimpleType.uri => 'text',
          },
        EnumType() || ReferenceType() => 'integer',
        ListType() || SetType() || MapType() => null,
      };

  String? get referencedTable => switch (this) {
        SimpleType() ||
        EnumType() ||
        ListType() ||
        SetType() ||
        MapType() =>
          null,
        ReferenceType(table: final referencedTable) => referencedTable.name,
      };

  Table? getDependencies() => switch (this) {
        SimpleType() ||
        EnumType() ||
        ListType() ||
        SetType() ||
        MapType() =>
          null,
        ReferenceType(table: final referencedTable) => referencedTable,
      };

  Table? getDependants(Table generated) => switch (this) {
        SimpleType() || EnumType() || ReferenceType() => null,
        ListType() ||
        SetType() ||
        MapType() =>
          (this as KeyedCollectionType).storageTableFor(generated),
      };

  Future<dynamic> decode(dynamic sql, PostgresDatabase database) async =>
      switch (this) {
        SimpleType() => switch (this as SimpleType) {
            SimpleType.regExp => RegExp(sql as String),
            SimpleType.uri => Uri.parse(sql as String),
            _ => sql,
          },
        EnumType() => sql,
        ReferenceType(table: final referencedTable) =>
          await database.get(referencedTable, sql as int),
        ListType() ||
        SetType() ||
        MapType() =>
          throw UnsupportedError('Cannot decode ListType, SetType or MapType'),
      };

  Future<dynamic> encode(dynamic dart, PostgresDatabase database) async =>
      switch (this) {
        SimpleType() => switch (this as SimpleType) {
            SimpleType.regExp => (dart as RegExp).pattern,
            SimpleType.uri => (dart as Uri).toString(),
            _ => dart,
          },
        EnumType() => dart,
        ReferenceType() => await database.insert(dart as Sql),
        ListType() ||
        SetType() ||
        MapType() =>
          throw UnsupportedError('Cannot encode ListType, SetType or MapType'),
      };

  Future<dynamic> fetch(int id, Table table, PostgresDatabase database) async =>
      switch (this) {
        SimpleType() || EnumType() || ReferenceType() => throw UnsupportedError(
            'Cannot fetch SimpleType, EnumType or ReferenceType'),
        ListType() || SetType() || MapType() => () async {
            final storageTable =
                (this as KeyedCollectionType).storageTableFor(table);

            final valueColumn = storageTable.columns
                .singleWhere((column) => column.name == 'value');
            final valueType = (this as KeyedCollectionType).valueType;

            final keyColumn = storageTable.columns
                .singleWhere((column) => column.name == 'key');
            final keyType = (this as KeyedCollectionType).keyType;

            final valueColumnName = valueType.hasColumn
                ? valueColumn.name
                : valueColumn.nullMarkerName;
            final keyColumnName =
                keyType.hasColumn ? keyColumn.name : keyColumn.nullMarkerName;

            final result = (await database.context.execute(
                    'SELECT id, "$keyColumnName", "$valueColumnName" FROM "${storageTable.name}" WHERE owner = @id;',
                    parameters: {
                  'id': id,
                }))
                .map((row) => row.toColumnMap());

            final mappedResult =
                Map.fromEntries(await Future.wait(result.map((row) async {
              final dynamic key;
              final dynamic value;

              if (keyType.hasColumn) {
                key = await keyType.decode(row[keyColumnName], database);
              } else {
                key = await keyType.fetch(row['id'], storageTable, database);
              }

              if (valueType.hasColumn) {
                value = await valueType.decode(row[valueColumnName], database);
              } else {
                value =
                    await valueType.fetch(row['id'], storageTable, database);
              }

              return MapEntry(key, value);
            })));

            if (this is MapType) {
              return mappedResult;
            } else if (this is SetType) {
              return mappedResult.values.toSet();
            } else if (this is ListType) {
              return List.generate(
                  mappedResult.length, (index) => mappedResult[index]);
            }
          }(),
      };

  Future<void> put(
    dynamic value,
    int id,
    Table table,
    PostgresDatabase database,
  ) async =>
      switch (this) {
        SimpleType() || EnumType() || ReferenceType() => throw UnsupportedError(
            'Cannot put SimpleType, EnumType or ReferenceType'),
        ListType() || SetType() || MapType() => () async {
            // Dynamic access because map and list/set don't have a common supertype
            if (value.isEmpty) {
              return;
            }

            final storageTable =
                (this as KeyedCollectionType).storageTableFor(table);
            final valueColumn = storageTable.columns
                .singleWhere((column) => column.name == 'value');
            final keyColumn = storageTable.columns
                .singleWhere((column) => column.name == 'key');

            final valueType = (this as KeyedCollectionType).valueType;
            final keyType = (this as KeyedCollectionType).keyType;

            final valueColumnName = valueType.hasColumn
                ? valueColumn.name
                : valueColumn.nullMarkerName;
            final keyColumnName =
                keyType.hasColumn ? keyColumn.name : keyColumn.nullMarkerName;

            if (value is List) {
              value = Map.fromEntries((value as List)
                  .mapIndexed((index, element) => MapEntry(index, element)));
            } else if (value is Set) {
              value = Map.fromEntries((value as Set)
                  .mapIndexed((index, element) => MapEntry(index, element)));
            } else {
              value = value as Map;
            }

            final values = [];

            final substitutions = {};
            int counter = 0;

            for (final entry in (value as Map).entries) {
              final valueName = 'value_$counter';
              final keyName = 'key_${counter++}';

              if (valueType.hasColumn) {
                if (entry.value == null) {
                  substitutions[valueName] = null;
                } else {
                  substitutions[valueName] =
                      await valueType.encode(entry.value, database);
                }
              } else {
                substitutions[valueName] = entry.value == null;
              }

              if (keyType.hasColumn) {
                if (entry.key == null) {
                  substitutions[keyName] = null;
                } else {
                  substitutions[keyName] =
                      await keyType.encode(entry.key, database);
                }
              } else {
                substitutions[keyName] = entry.key == null;
              }

              values.add('(@owner, @$keyName, @$valueName)');
            }

            final result = await database.context.execute(
              'INSERT INTO "${storageTable.name}" (owner, "$keyColumnName", "$valueColumnName") VALUES ${values.join(', ')} RETURNING id;',
              parameters: {
                ...substitutions,
                'owner': id,
              },
            );

            for (final rowAndEntry in IterableZip(
                <Iterable<dynamic>>[result, (value as Map).entries])) {
              final row = rowAndEntry[0] as pg.ResultRow;
              final entry = rowAndEntry[1] as MapEntry;

              final id = row.toColumnMap()['id'] as int;

              if (!valueType.hasColumn) {
                await valueType.put(entry.value, id, storageTable, database);
              }

              if (!keyType.hasColumn) {
                await keyType.put(entry.key, id, storageTable, database);
              }
            }
          }(),
      };
}

extension PostgresColumn on Column {
  String get nullMarkerName => '_${name}_is_null';
}
