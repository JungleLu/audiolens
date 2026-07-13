import 'package:flutter/material.dart';

@immutable
class WordAnalysis {
  const WordAnalysis({
    required this.word,
    required this.phoneticUk,
    required this.phoneticUs,
    required this.partOfSpeech,
    required this.meaning,
    required this.collocations,
    required this.wordRoot,
  });

  final String word;
  final String phoneticUk;
  final String phoneticUs;
  final String partOfSpeech;
  final String meaning;
  final List<String> collocations;
  final String wordRoot;

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic_uk': phoneticUk,
        'phonetic_us': phoneticUs,
        'part_of_speech': partOfSpeech,
        'meaning': meaning,
        'collocations': collocations,
        'word_root': wordRoot,
      };

  factory WordAnalysis.fromJson(Map<String, dynamic> json) => WordAnalysis(
        word: (json['word'] ?? '').toString(),
        phoneticUk: (json['phonetic_uk'] ?? '').toString(),
        phoneticUs: (json['phonetic_us'] ?? '').toString(),
        partOfSpeech: (json['part_of_speech'] ?? '').toString(),
        meaning: (json['meaning'] ?? '').toString(),
        collocations: _stringList(json['collocations']),
        wordRoot: (json['word_root'] ?? '').toString(),
      );
}

@immutable
class SentenceAnalysis {
  const SentenceAnalysis({
    required this.sentence,
    required this.translation,
    required this.structure,
    required this.grammarNotes,
    required this.slangNotes,
    required this.paraphrases,
  });

  final String sentence;
  final String translation;
  final List<String> structure;
  final List<String> grammarNotes;
  final List<String> slangNotes;
  final List<String> paraphrases;

  Map<String, dynamic> toJson() => {
        'sentence': sentence,
        'translation': translation,
        'structure': structure,
        'grammar_notes': grammarNotes,
        'slang_notes': slangNotes,
        'paraphrases': paraphrases,
      };

  factory SentenceAnalysis.fromJson(Map<String, dynamic> json) => SentenceAnalysis(
        sentence: (json['sentence'] ?? '').toString(),
        translation: (json['translation'] ?? '').toString(),
        structure: _stringList(json['structure']),
        grammarNotes: _stringList(json['grammar_notes']),
        slangNotes: _stringList(json['slang_notes']),
        paraphrases: _stringList(json['paraphrases']),
      );
}

@immutable
class AnalysisResult {
  const AnalysisResult({
    required this.source,
    required this.word,
    required this.sentence,
    required this.timestampMs,
  });

  final String source;
  final WordAnalysis word;
  final SentenceAnalysis sentence;
  final int timestampMs;

  Map<String, dynamic> toJson() => {
        'source': source,
        'timestamp_ms': timestampMs,
        'word': word.toJson(),
        'sentence': sentence.toJson(),
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        source: (json['source'] ?? '').toString(),
        timestampMs: (json['timestamp_ms'] as num?)?.toInt() ?? 0,
        word: WordAnalysis.fromJson(
          (json['word'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        sentence: SentenceAnalysis.fromJson(
          (json['sentence'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}
