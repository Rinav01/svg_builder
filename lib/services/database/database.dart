import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Table storing local project metadata and draft snapshots for auto-save.
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant('Untitled Project'))();
  TextColumn get jsonContent => text()(); // Serialized .svgb Document JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Saves or updates the project draft snapshot.
  Future<void> saveDraft({
    required String projectId,
    required String name,
    required String jsonContent,
  }) async {
    await into(projects).insertOnConflictUpdate(
      ProjectsCompanion(
        id: Value(projectId),
        name: Value(name),
        jsonContent: Value(jsonContent),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Retrieves the latest saved project draft.
  Future<Project?> getLatestDraft() async {
    final query = select(projects)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Lists all saved local projects.
  Future<List<Project>> getAllProjects() async {
    final query = select(projects)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.get();
  }

  /// Deletes a project by id.
  Future<int> deleteProject(String id) {
    return (delete(projects)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'svg_builder_store.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
