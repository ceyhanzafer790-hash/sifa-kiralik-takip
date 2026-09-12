import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openDatabaseConnection() {
  return WebDatabase('sifa_kiralik_cache');
}
