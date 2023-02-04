# sql_serializable

A code generator & runtime library for converting Dart classes to/from SQL.

### Getting started

Add this package and [`build_runner`](https://pub.dev/packages/build_runner) as a dev dependency & one of the [runtime packages](#runtime-packages) as a normal dependency:
```
$ dart pub add -d sql_serializable build_runner
$ dart pub add sql_serializable_postgres
```

Import the runtime library & annotate the class you want to convert to SQL:
```dart
import "package:sql_serializable_postgres/sql_serializable_postgres.dart";

@SqlSerializable()
class MyClass {
    ...
}
```

Add the generated file as a part and add a `static const table` field to your class that points to the to-be-generated table. Add a `toJson` and `fromJson` method to your class that redirect to the generated functions if you want to easily access them:
```dart
import "package:sql_serializable_postgres/sql_serializable_postgres.dart";

part 'my_file.g.dart';

@SqlSerializable()
class MyClass {
    static const table = _$MyClassTable;

    factory MyClass.fromSql(Sql<MyClass> sql) => _$MyClassFromSql(sql);
    Sql<MyClass> toSql() => _$MyClassToSql(this);

    ...
}
```

Run the build runner:
```
$ dart run build_runner build
```

Create a database from one of the [runtime packages](#runtime-packages) to insert your models:
```dart
void main() async {
    final model = MyClass(...);
    final database = ...;

    final id = await database.insert(model.toSql());
    final fromDatabase = MyClass.fromSql(await database.get(MyClass.table, id));
}
```

### Runtime packages
sql_serializable provides the following packages for interacting with databases at runtime:
- [sql_serializable_postgres](https://pub.dev/packages/sql_serializable_postgres) for PostgreSQL databases.

### Why do I need a `static const table` on my classes?
When a class contains a field that is itself another class annotated with `SqlSerializable`, `sql_serializable` needs to know which table represents that class to refer to it in the table definition. If that other class is in a different library than the current one, `sql_serializable` cannot access the generated `_$ClassNameTable` for that class, so we require that all classes annotated with `SqlSerializable()` provide a public getter for the generated table.

It must also be const since all generated table instances are themselves const, so they cannot refer to non-const elements.
