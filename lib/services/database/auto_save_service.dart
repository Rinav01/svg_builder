import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/core.dart';
import '../compute_isolate_service.dart';
import 'database.dart';

/// Current background persistence status for the live studio HUD indicator.
enum AutoSaveStatus {
  idle,
  saving,
  saved,
  error,
}

/// Background service debouncing document changes, encoding JSON in a worker Isolate,
/// and persisting drafts to SQLite.
class AutoSaveService {
  AutoSaveService({
    required this.database,
    this.debounceDuration = const Duration(milliseconds: 1500),
  });

  final AppDatabase database;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  String currentProjectId = 'default_project';
  String currentProjectName = 'Untitled Project';

  final ValueNotifier<AutoSaveStatus> statusNotifier =
      ValueNotifier<AutoSaveStatus>(AutoSaveStatus.idle);

  /// Listens to document changes and schedules an isolate-backed auto-save.
  void scheduleAutoSave(Document document) {
    _debounceTimer?.cancel();
    statusNotifier.value = AutoSaveStatus.saving;
    _debounceTimer = Timer(debounceDuration, () async {
      try {
        final projectId = currentProjectId;
        final projectName = currentProjectName;
        final json = await ComputeIsolateService.encodeProjectAsync(document);
        await database.saveDraft(
          projectId: projectId,
          name: projectName,
          jsonContent: json,
        );
        statusNotifier.value = AutoSaveStatus.saved;
        debugPrint('[AutoSave] Saved draft for project "$projectName" (via Isolate)');
      } catch (e) {
        statusNotifier.value = AutoSaveStatus.error;
        debugPrint('[AutoSave] Error saving draft: $e');
      }
    });
  }

  /// Immediately persists the document without debounce delay (e.g. on app pause or navigation).
  Future<void> saveImmediately(Document document) async {
    _debounceTimer?.cancel();
    statusNotifier.value = AutoSaveStatus.saving;
    try {
      // Encode synchronously or via fast path so Android lifecycle pause completes before OS suspension.
      final json = ProjectFormat.encode(document);
      await database.saveDraft(
        projectId: currentProjectId,
        name: currentProjectName,
        jsonContent: json,
      );
      statusNotifier.value = AutoSaveStatus.saved;
      debugPrint('[AutoSave] Immediately saved draft for project "$currentProjectName"');
    } catch (e) {
      statusNotifier.value = AutoSaveStatus.error;
      debugPrint('[AutoSave] Error saving draft immediately: $e');
    }
  }

  /// Cancels any scheduled timer.
  void dispose() {
    _debounceTimer?.cancel();
    statusNotifier.dispose();
  }
}
