import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('NotebookRow')
class NotebookEntries extends Table {
  TextColumn get id => text()();
  TextColumn get word => text()();
  TextColumn get sentence => text()();
  TextColumn get meaning => text()();
  IntColumn get timestampMs => integer()();
  TextColumn get source => text()();
  TextColumn get videoId => text()();

  /// Full serialized [AnalysisResult] so cards can render the complete
  /// word + sentence breakdown and support re-analysis.
  TextColumn get analysisJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [NotebookEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<List<NotebookRow>> allEntries() {
    return (select(notebookEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> upsertEntry(NotebookEntriesCompanion entry) {
    return into(notebookEntries).insertOnConflictUpdate(entry);
  }

  Future<void> deleteEntry(String id) {
    return (delete(notebookEntries)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'audiolens.sqlite'));
    return NativeDatabase(file);
  });
}
