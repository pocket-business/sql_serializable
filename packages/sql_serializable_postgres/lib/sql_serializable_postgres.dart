/// PostgreSQL support for sql_serializable.
///
/// This is the runtime package.
library sql_serializable_postgres;

export 'package:sql_serializable/sql_serializable.dart';

export 'src/database.dart';
export 'src/migrations.dart';
export 'src/result_extension.dart';
