import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/domain/analysis_models.dart';
import '../../notebook/domain/notebook_entry.dart';
import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final notebookRepositoryProvider = Provider<NotebookRepository>((ref) {
  return NotebookRepository(ref.watch(appDatabaseProvider));
});

class NotebookRepository {
  NotebookRepository(this._db);

  final AppDatabase _db;

  /// Stable identity for a saved card so re-saving the same word at the same
  /// timestamp of the same video updates in place instead of duplicating.
  static String buildId({required String videoId, required int timestampMs, required String word}) {
    return '${videoId}_${timestampMs}_${word.toLowerCase().trim()}';
  }

  Future<List<NotebookEntry>> listEntries() async {
    final rows = await _db.allEntries();
    return rows.map(_toEntry).toList();
  }

  Future<void> saveAnalysis({required AnalysisResult entry, required String videoId}) async {
    final id = buildId(videoId: videoId, timestampMs: entry.timestampMs, word: entry.word.word);
    await _db.upsertEntry(
      NotebookEntriesCompanion.insert(
        id: id,
        word: entry.word.word,
        sentence: entry.sentence.sentence,
        meaning: entry.word.meaning,
        timestampMs: entry.timestampMs,
        source: entry.source,
        videoId: videoId,
        analysisJson: Value(jsonEncode(entry.toJson())),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteEntry(String id) => _db.deleteEntry(id);

  NotebookEntry _toEntry(NotebookRow row) {
    AnalysisResult analysis;
    try {
      analysis = AnalysisResult.fromJson(jsonDecode(row.analysisJson) as Map<String, dynamic>);
    } catch (_) {
      analysis = AnalysisResult(
        source: row.source,
        timestampMs: row.timestampMs,
        word: WordAnalysis(
          word: row.word,
          phoneticUk: '',
          phoneticUs: '',
          partOfSpeech: '',
          meaning: row.meaning,
          collocations: const [],
          wordRoot: '',
        ),
        sentence: SentenceAnalysis(
          sentence: row.sentence,
          translation: '',
          structure: const [],
          grammarNotes: const [],
          slangNotes: const [],
          paraphrases: const [],
        ),
      );
    }

    return NotebookEntry(
      id: row.id,
      word: row.word,
      sentence: row.sentence,
      meaning: row.meaning,
      timestampMs: row.timestampMs,
      videoId: row.videoId,
      source: row.source,
      analysis: analysis,
      createdAt: row.createdAt,
    );
  }
}
