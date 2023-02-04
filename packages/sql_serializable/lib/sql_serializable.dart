/// A code generator & runtime library for converting Dart classes to/from SQL.
///
/// You should not import this library - instead, import one of the
/// [runtime libraries](https://pub.dev/packages/sql_serializable/#runtime-packages) that export
/// this library.
library sql_serializable;

export 'src/annotation.dart';
export 'src/sql.dart';
export 'src/sql_type.dart';
export 'src/exceptions.dart';

export 'src/runtime/database.dart';
