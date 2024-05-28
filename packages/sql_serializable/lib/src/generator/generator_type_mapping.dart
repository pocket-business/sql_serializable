import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';
import 'package:sql_serializable/sql_serializable.dart';

/// Get the [SimpleType] for [type], if it exists.
SimpleType? simpleTypeFor(DartType type) {
  final element = type.element;
  final library = element?.library;

  if (element == null || library == null) {
    return null;
  }

  final name = element.name;

  if (library.isDartCore) {
    const mapping = {
      'BigInt': SimpleType.bigInt,
      'bool': SimpleType.boolean,
      'DateTime': SimpleType.dateTime,
      'double': SimpleType.double_,
      'Duration': SimpleType.duration,
      'int': SimpleType.integer,
      'num': SimpleType.number,
      'RegExp': SimpleType.regExp,
      'String': SimpleType.string,
      'Uri': SimpleType.uri,
    };

    return mapping[name];
  }

  return null;
}

/// Get the serialized converter for a given [type].
///
/// [name] is provided for collection types that might need to generate a new table.
String serializedConverterFor({
  required String name,
  required DartType type,
  required LibraryElement library,
}) {
  type = library.typeSystem.resolveToBound(type);

  final builtInType = simpleTypeFor(type);
  if (builtInType != null) {
    return 'SimpleType.${builtInType.name}';
  }

  if (type.isEnum) {
    return 'EnumType(${type.element!.name}.values)';
  }

  if (type is! InterfaceType) {
    throw Exception(
        'Unsupported type: ${type.getDisplayString(withNullability: false)}');
  }

  if (type.isDartCoreList || type.isDartCoreSet) {
    final innerType = serializedConverterFor(
      name: "${name}_list",
      type: type.typeArguments.first,
      library: library,
    );

    final isNullable = type.typeArguments.first.isNullableType;
    final serializedName = escapeDartString("${name}_list");

    final String typeName;
    if (type.isDartCoreList) {
      typeName = 'NullableListType';
    } else {
      typeName = 'NullableSetType';
    }

    return '${isNullable ? '' : 'Non'}$typeName(name: $serializedName, valueType: $innerType,)';
  }

  if (type.isDartCoreMap) {
    final keyType = serializedConverterFor(
      name: "${name}_key",
      type: type.typeArguments.first,
      library: library,
    );

    final valueType = serializedConverterFor(
      name: "${name}_value",
      type: type.typeArguments.last,
      library: library,
    );

    final keyIsNullable = type.typeArguments.first.isNullableType;
    final valueIsNullable = type.typeArguments.last.isNullableType;
    final serializedName = escapeDartString("${name}_map");

    final typeName =
        '${keyIsNullable ? '' : 'Non'}NullableKey${valueIsNullable ? '' : 'Non'}NullableValueMapType';

    return '$typeName(name: $serializedName, keyType: $keyType, valueType: $valueType,)';
  }

  final table = type.element.fields.singleWhere(
    // (element) => element.isStatic && element.isConst && element.name == 'table',
    (element) => element.name == 'table',
    orElse: () => throw Exception(
      'Unsupported type: ${type.getDisplayString(withNullability: false)}'
      ' must provide a static const table field',
    ),
  );

  // dynamic most likely indicates an ungenerated reference.
  if (table.type is! DynamicType) {
    final tableType = TypeChecker.fromRuntime(Table);

    if (!tableType.isAssignableFromType(table.type)) {
      throw Exception(
        'Unsupported type: ${type.getDisplayString(withNullability: false)}'
        ' must return Table from its table field',
      );
    }
  }

  return 'ReferenceType(${type.element.name}.table)';
}
