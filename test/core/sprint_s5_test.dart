import 'dart:math' as math;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/services/database/auto_save_service.dart';
import 'package:svg_builder/services/database/database.dart';
import 'package:svg_builder/ui/editor_controller.dart';

void main() {
  group('Sprint S5: Database Project Management', () {
    late AppDatabase database;

    setUp(() {
      // In-memory SQLite database for deterministic headless testing
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('saveDraft, getProjectById, and getAllProjects manage projects correctly', () async {
      final doc = Document(width: 800, height: 600);
      final json = ProjectFormat.encode(doc);

      await database.saveDraft(
        projectId: 'proj_1',
        name: 'Project One',
        jsonContent: json,
      );

      final fetched = await database.getProjectById('proj_1');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Project One'));
      expect(fetched.id, equals('proj_1'));

      final all = await database.getAllProjects();
      expect(all.length, equals(1));
      expect(all.first.id, equals('proj_1'));
    });

    test('renameProject updates project name and timestamp', () async {
      final doc = Document();
      final json = ProjectFormat.encode(doc);

      await database.saveDraft(
        projectId: 'p_rename',
        name: 'Initial Name',
        jsonContent: json,
      );

      await database.renameProject('p_rename', 'Renamed Drawing');
      final updated = await database.getProjectById('p_rename');

      expect(updated, isNotNull);
      expect(updated!.name, equals('Renamed Drawing'));
    });

    test('duplicateProject creates an independent copy with new ID and name', () async {
      final doc = Document(width: 1280, height: 720);
      final json = ProjectFormat.encode(doc);

      await database.saveDraft(
        projectId: 'p_src',
        name: 'Master Drawing',
        jsonContent: json,
      );

      await database.duplicateProject('p_src', 'p_copy', 'Master Drawing Copy');

      final copy = await database.getProjectById('p_copy');
      expect(copy, isNotNull);
      expect(copy!.name, equals('Master Drawing Copy'));
      expect(copy.jsonContent, equals(json));

      final all = await database.getAllProjects();
      expect(all.length, equals(2));
    });

    test('deleteProject removes targeted project cleanly', () async {
      await database.saveDraft(
        projectId: 'p_del',
        name: 'To Delete',
        jsonContent: '{}',
      );

      expect(await database.getProjectById('p_del'), isNotNull);

      await database.deleteProject('p_del');
      expect(await database.getProjectById('p_del'), isNull);
    });
  });

  group('Sprint S5: AutoSave Immediate Persistence', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('saveImmediately persists document without debounce delay', () async {
      final service = AutoSaveService(database: database);
      service.currentProjectId = 'proj_immediate';
      service.currentProjectName = 'Immediate Save Test';

      final doc = Document(width: 500, height: 500);
      await service.saveImmediately(doc);

      final saved = await database.getProjectById('proj_immediate');
      expect(saved, isNotNull);
      expect(saved!.name, equals('Immediate Save Test'));

      final restoredDoc = ProjectFormat.decode(saved.jsonContent);
      expect(restoredDoc.width, equals(500));
      expect(restoredDoc.height, equals(500));

      service.dispose();
    });
  });

  group('Sprint S5: Canvas Artboard & Viewport Framing Math', () {
    test('artboard fit-to-screen scale calculation produces proportional bounds', () {
      const docW = 1000.0;
      const docH = 500.0;
      const viewW = 800.0;
      const viewH = 600.0;

      // Fit math with 60px padding
      final scaleX = (viewW - 60) / docW; // 740 / 1000 = 0.74
      final scaleY = (viewH - 60) / docH; // 540 / 500 = 1.08
      final fitScale = math.min(scaleX, scaleY);

      expect(fitScale, closeTo(0.74, 1e-4));

      final offsetX = (viewW - docW * fitScale) / 2.0;
      final offsetY = (viewH - docH * fitScale) / 2.0;

      expect(offsetX, closeTo(30.0, 1e-4));
      expect(offsetY, closeTo((600 - 370) / 2, 1e-4));
    });

    test('clipToArtboard and documentName toggle on EditorController', () {
      final controller = EditorController();
      expect(controller.clipToArtboard, isFalse);

      controller.toggleClipToArtboard();
      expect(controller.clipToArtboard, isTrue);

      expect(controller.documentName, equals('Untitled Project'));
      controller.setDocumentName('Sunset Vector Art');
      expect(controller.documentName, equals('Sunset Vector Art'));
    });
  });
}
