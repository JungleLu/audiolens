import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/analysis_service.dart';
import '../../ai_settings/application/ai_settings_controller.dart';
import '../../storage/data/notebook_repository.dart';
import '../domain/notebook_entry.dart';

final notebookControllerProvider =
    AsyncNotifierProvider<NotebookController, List<NotebookEntry>>(
        NotebookController.new);

class NotebookController extends AsyncNotifier<List<NotebookEntry>> {
  @override
  Future<List<NotebookEntry>> build() async {
    final repository = ref.read(notebookRepositoryProvider);
    return repository.listEntries();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(notebookRepositoryProvider).listEntries());
  }

  Future<void> deleteEntry(String id) async {
    final repository = ref.read(notebookRepositoryProvider);
    await repository.deleteEntry(id);
    await refresh();
  }

  /// Re-run AI analysis for a saved card and overwrite it in place.
  Future<void> reanalyze(NotebookEntry entry) async {
    final service = ref.read(analysisServiceProvider);
    final preferCustom =
        ref.read(aiSettingsControllerProvider).preferCustomModel;
    final result = await service.analyzeSubtitleSelection(
      word: entry.word,
      sentence: entry.sentence,
      timestampMs: entry.timestampMs,
      hasNetwork: true,
      preferCustom: preferCustom,
    );
    await ref
        .read(notebookRepositoryProvider)
        .saveAnalysis(entry: result, videoId: entry.videoId);
    await refresh();
  }
}
