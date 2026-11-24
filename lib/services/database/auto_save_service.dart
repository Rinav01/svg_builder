import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/core.dart';
import 'database.dart';

/// Background service debouncing document changes and persisting drafts to SQLite.
class AutoSaveService {
  AutoSaveService({required this.database, this.debounceDuration = const Duration(milliseconds: 1500)});

  final AppDatabase database;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  String currentProjectId = 'default_project';
  String currentProjectName = 'Untitled Project';

  /// Listens to document changes and schedules an auto-save.
  void scheduleAutoSave(Document document) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () async {
      try {
        final json = ProjectFormat.encode(document);
        await database.saveDraft(
          projectId: currentProjectId,
          name: currentProjectName,
          jsonContent: json,
        );
        debugPrint('[AutoSave] Saved draft for project "$currentProjectName"');
      } catch (e) {
        debugPrint('[AutoSave] Error saving draft: $e');
      }
    });
  }

  /// Immediately persists the document without debounce delay (e.g. on app pause or navigation).
  Future<void> saveImmediately(Document document) async {
    _debounceTimer?.cancel();
    try {
      final json = ProjectFormat.encode(document);
      await database.saveDraft(
        projectId: currentProjectId,
        name: currentProjectName,
        jsonContent: json,
      );
      debugPrint('[AutoSave] Immediately saved draft for project "$currentProjectName"');
    } catch (e) {
      debugPrint('[AutoSave] Error saving draft immediately: $e');
    }
  }

  /// Cancels any scheduled timer.
  void dispose() {
    _debounceTimer?.cancel();
  }
}
