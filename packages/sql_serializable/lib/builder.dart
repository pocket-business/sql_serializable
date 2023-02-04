import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:sql_serializable/src/generator/sql_serializable.dart';

/// The builder for `sql_serializable`. Users will not normally access this manually.
Builder sqlSerializable(BuilderOptions options) => SharedPartBuilder(
      [SqlSerializableGenerator()],
      'sql_serializable',
    );
