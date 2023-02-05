import 'package:collection/collection.dart';
import 'package:sql_serializable/sql_serializable.dart';

/// A converter between native Dart and an intermediary, database agnostic representation of SQL.
sealed class SqlType<Dart, Sql> {
  /// Convert [dart] to a database agnostic sql representation.
  Sql toSql(Dart dart);

  /// Convert [sql] back to Dart.
  Dart fromSql(Sql sql);
}

/// A simple sql type that performs no conversion.
enum SimpleType<T> implements SqlType<T, T> {
  /// A big integer.
  bigInt<BigInt>(),

  /// A boolean.
  boolean<bool>(),

  /// A date-time.
  dateTime<DateTime>(),

  /// A double.
  double_<double>(),

  /// A duration.
  duration<Duration>(),

  /// An integer.
  integer<int>(),

  /// A number.
  number<num>(),

  /// A regular expression.
  /// 
  /// Note that some runtime packages do not account for flags.
  regExp<RegExp>(),

  /// A string.
  string<String>(),

  /// A URI.
  uri<Uri>();

  @override
  T toSql(T dart) => dart;

  @override
  T fromSql(T sql) => sql;

}

/// An enumerated type.
class EnumType<T extends Enum> implements SqlType<T, int> {
  /// The values of this enum.
  /// 
  /// The index of a value in this list provides the SQL representation of that value, so you should
  /// avoid modifying the order of the members of this enum between database connections.
  final List<T> values;

  const EnumType(this.values);

  @override
  int toSql(T dart) => dart.index;

  @override
  T fromSql(int sql) => values[sql];

  @override
  int get hashCode => ListEquality().hash(values);

  @override
  bool operator ==(Object other) => identical(this, other) ||
    (other is EnumType<T> && ListEquality().equals(values, other.values));
}

/// A reference to another type, normally stored in a separate table.
class ReferenceType<T> implements SqlType<T, Sql<T>> {
  /// The table referenced by this type.
  final Table<T> table;

  const ReferenceType(this.table);

  @override
  Sql<T> toSql(T dart) => table.toSql(dart);

  @override
  T fromSql(Sql<T> sql) => table.fromSql(sql);

  @override
  int get hashCode => table.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) ||
    (other is ReferenceType<T> && other.table == table);
}

/// A multi-element collection where each element is identified by a key.
/// 
/// The key of a [List] is taken to be its index.
/// The key of a [Set] is arbitrary but unique per set.
mixin KeyedCollectionType<DartKey, DartValue, SqlKey, SqlValue> {
  /// The name of the column this type is for.
  /// 
  /// Used to generate the name of the table to store this type's elements.
  String get name;

  /// The type of this collection's keys.
  /// 
  /// For [List]s and [Set]s, this is always [SimpleType.integer].
  SqlType<DartKey, SqlKey> get keyType;

  /// The type of this collection's values.
  SqlType<DartValue, SqlValue> get valueType;

  /// Whether the keys of this collection are nullable.
  /// 
  /// This is always [false] for [List]s and [Set]s.
  bool get isKeyNullable;

  /// Whether the values of this collection are nullable.
  bool get isValueNullable;

  /// Get the configuration of the table used to store this type's element.
  /// 
  /// [owner] is the table in which the column this type is for appears.
  Table storageTableFor(Table owner) => Table(
    name: '${owner.name}_$name',
    fromSql: (_) => throw 'unreachable',
    toSql: (_) => throw 'unreachable',
    columns: [
      Column(name: 'owner', type: ReferenceType(owner), isNullable: false),
      Column(name: 'key', type: keyType, isNullable: isKeyNullable),
      Column(name: 'value', type: valueType, isNullable: isValueNullable),
    ],
  );

  @override
  int get hashCode => Object.hash(name, keyType, valueType, isKeyNullable, isValueNullable);

  @override
  bool operator ==(Object other) => identical(this, other) ||
    (other is MapType<DartKey, DartValue, SqlKey, SqlValue>
    && name == other.name
    && keyType == other.keyType
    && valueType == other.valueType
    && other.isKeyNullable == isKeyNullable
    && other.isValueNullable == isValueNullable);
}

/// A [List].
abstract class ListType<Dart, Sql>
  with KeyedCollectionType<int, Dart, int, Sql>
  implements SqlType<List<Dart>, List> {
  
  @override
  final String name;

  @override
  bool get isKeyNullable => false;

  @override
  SqlType<int, int> get keyType => SimpleType.integer;

  const ListType._({required this.name});
}

/// A [List] where the elements are known to not be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NonNullableListType<Dart, Sql> extends ListType<Dart, Sql> {
  @override
  bool get isValueNullable => false;

  @override
  final SqlType<Dart, Sql> valueType;
  
  const NonNullableListType({required super.name, required this.valueType}) : super._();

  @override
  List<Sql> toSql(List<Dart> dart) => dart.map(valueType.toSql).toList();

  @override
  List<Dart> fromSql(List sql) => sql.cast<Sql>().map(valueType.fromSql).toList();
}

/// A [List] where the elements may be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NullableListType<Dart, Sql> extends ListType<Dart?, Sql?> {
  @override
  bool get isValueNullable => true;

  @override
  final SqlType<Dart, Sql> valueType;

  const NullableListType({required super.name, required this.valueType}) : super._();

  @override
  List<Sql?> toSql(List<Dart?> dart) =>
    dart.map((value) => value != null ? valueType.toSql(value) : null).toList();

  @override
  List<Dart?> fromSql(List sql) =>
    sql.cast<Sql?>().map((value) => value != null ? valueType.fromSql(value) : null).toList();
}

/// A [Set].
abstract class SetType<Dart, Sql>
  with KeyedCollectionType<int, Dart, int, Sql>
  implements SqlType<Set<Dart>, List> {

  @override
  final String name;

  @override
  bool get isKeyNullable => false;

  @override
  SqlType<int, int> get keyType => SimpleType.integer;

  const SetType._({required this.name});
}

/// A [Set] where the elements are known to not be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NonNullableSetType<Dart, Sql> extends SetType<Dart, Sql> {
  @override
  bool get isValueNullable => false;

  @override
  final SqlType<Dart, Sql> valueType;
  
  const NonNullableSetType({required super.name, required this.valueType}) : super._();

  @override
  List<Sql> toSql(Set<Dart> dart) => dart.map(valueType.toSql).toList();

  @override
  Set<Dart> fromSql(List sql) => sql.cast<Sql>().map(valueType.fromSql).toSet();
}
/// A [Set] where the elements may be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NullableSetType<Dart, Sql> extends SetType<Dart?, Sql?> {
  @override
  bool get isValueNullable => true;

  @override
  final SqlType<Dart, Sql> valueType;

  const NullableSetType({required super.name, required this.valueType}) : super._();

  @override
  List<Sql?> toSql(Set<Dart?> dart) =>
    dart.map((value) => value != null ? valueType.toSql(value) : null).toList();

  @override
  Set<Dart?> fromSql(List sql) =>
    sql.cast<Sql?>().map((value) => value != null ? valueType.fromSql(value) : null).toSet();
}

/// A [Map].
abstract class MapType<DartKey, DartValue, SqlKey, SqlValue>
  with KeyedCollectionType<DartKey, DartValue, SqlKey, SqlValue>
  implements SqlType<Map<DartKey, DartValue>, Map> {

  @override
  final String name;

  const MapType._({required this.name});
}

/// A [Map] where the keys and values are known to not be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NonNullableKeyNonNullableValueMapType<DartKey, DartValue, SqlKey, SqlValue>
  extends MapType<DartKey, DartValue, SqlKey, SqlValue> {

  @override
  bool get isKeyNullable => false;
  
  @override
  bool get isValueNullable => false;
  
  @override
  final SqlType<DartKey, SqlKey> keyType;
  
  @override
  final SqlType<DartValue, SqlValue> valueType;

  const NonNullableKeyNonNullableValueMapType({
    required super.name,
    required this.keyType,
    required this.valueType,
  }) : super._();

  @override
  Map<DartKey, DartValue> fromSql(Map sql) => sql.map(
    (key, value) => MapEntry(keyType.fromSql(key), valueType.fromSql(value)),
  );
  
  @override
  Map<SqlKey, SqlValue> toSql(Map<DartKey, DartValue> dart) => dart.map(
    (key, value) => MapEntry(keyType.toSql(key), valueType.toSql(value)),
  );
}

/// A [Map] where the keys may be null and the values are known to not be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NullableKeyNonNullableValueMapType<DartKey, DartValue, SqlKey, SqlValue>
  extends MapType<DartKey?, DartValue, SqlKey?, SqlValue> {

  @override
  bool get isKeyNullable => true;
  
  @override
  bool get isValueNullable => false;
  
  @override
  final SqlType<DartKey, SqlKey> keyType;
  
  @override
  final SqlType<DartValue, SqlValue> valueType;

  const NullableKeyNonNullableValueMapType({
    required super.name,
    required this.keyType,
    required this.valueType,
  }) : super._();

  @override
  Map<DartKey?, DartValue> fromSql(Map sql) => sql.map(
    (key, value) => MapEntry(key != null ? keyType.fromSql(key) : null, valueType.fromSql(value)),
  );
  
  @override
  Map<SqlKey?, SqlValue> toSql(Map<DartKey?, DartValue> dart) => dart.map(
    (key, value) => MapEntry(key != null ? keyType.toSql(key) : null, valueType.toSql(value)),
  );
}

/// A [Map] where the keys are known to not be null and the values may be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NonNullableKeyNullableValueMapType<DartKey, DartValue, SqlKey, SqlValue>
  extends MapType<DartKey, DartValue?, SqlKey, SqlValue?> {

  @override
  bool get isKeyNullable => false;
  
  @override
  bool get isValueNullable => true;
  
  @override
  final SqlType<DartKey, SqlKey> keyType;
  
  @override
  final SqlType<DartValue, SqlValue> valueType;

  const NonNullableKeyNullableValueMapType({
    required super.name,
    required this.keyType,
    required this.valueType,
  }) : super._();

  @override
  Map<DartKey, DartValue?> fromSql(Map sql) => sql.map(
    (key, value) => MapEntry(keyType.fromSql(key), value != null ? valueType.fromSql(value) : null),
  );
  
  @override
  Map<SqlKey, SqlValue?> toSql(Map<DartKey, DartValue?> dart) => dart.map(
    (key, value) => MapEntry(keyType.toSql(key), value != null ? valueType.toSql(value) : null),
  );
}


/// A [Map] where the keys and values may be null.
/// 
/// This class only exists to satisfy issues with type arguments. It may be removed in the future if
/// Dart implements different variance rules.
class NullableKeyNullableValueMapType<DartKey, DartValue, SqlKey, SqlValue>
  extends MapType<DartKey?, DartValue?, SqlKey?, SqlValue?> {

  @override
  bool get isKeyNullable => true;
  
  @override
  bool get isValueNullable => true;
  
  @override
  final SqlType<DartKey, SqlKey> keyType;
  
  @override
  final SqlType<DartValue, SqlValue> valueType;

  const NullableKeyNullableValueMapType({
    required super.name,
    required this.keyType,
    required this.valueType,
  }) : super._();

  @override
  Map<DartKey?, DartValue?> fromSql(Map sql) => sql.map(
    (key, value) => MapEntry(
      key != null ? keyType.fromSql(key) : null,
      value != null ? valueType.fromSql(value) : null,
    ),
  );
  
  @override
  Map<SqlKey?, SqlValue?> toSql(Map<DartKey?, DartValue?> dart) => dart.map(
    (key, value) => MapEntry(
      key != null ? keyType.toSql(key) : null,
      value != null ? valueType.toSql(value) : null,
    ),
  );
}

