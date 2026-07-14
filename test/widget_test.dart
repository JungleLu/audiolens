import 'package:audiolens/src/features/ai/domain/analysis_models.dart';
import 'package:audiolens/src/features/player/application/subtitle_parser.dart';
import 'package:audiolens/src/features/storage/data/notebook_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubtitleParser', () {
    const parser = SubtitleParser();

    test('parses bilingual SRT into cues with word tokens', () {
      const srt = '''
1
00:00:01,000 --> 00:00:03,500
Hello there, friend!
你好，朋友！
''';
      final cues = parser.parse(srt);

      expect(cues, hasLength(1));
      final cue = cues.single;
      expect(cue.startMs, 1000);
      expect(cue.endMs, 3500);
      expect(cue.english, 'Hello there, friend!');
      expect(cue.chinese, '你好，朋友！');
      // Word tokens exclude punctuation/whitespace.
      final words =
          cue.tokens.where((t) => t.isWord).map((t) => t.text).toList();
      expect(words, ['Hello', 'there', 'friend']);
    });

    test('skips malformed blocks', () {
      const srt = '''
1
not-a-timestamp
broken block
''';
      expect(parser.parse(srt), isEmpty);
    });

    test('drops ASS vector-drawing coordinates, keeps real text', () {
      const ass = '''
[Script Info]
Title: sample

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\\p1}m 211 -8 b 217 -6 217 -4{\\p0}
Dialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,{\\pos(100,200)}'cause you're there for me too.
''';
      final cues = parser.parse(ass);

      expect(cues, hasLength(1));
      expect(cues.single.english, "'cause you're there for me too.");
    });
  });

  group('NotebookRepository.buildId', () {
    test('is stable and case-insensitive for dedup', () {
      final a = NotebookRepository.buildId(
          videoId: 'v1', timestampMs: 1000, word: 'Drift');
      final b = NotebookRepository.buildId(
          videoId: 'v1', timestampMs: 1000, word: 'drift ');
      expect(a, b);
    });

    test('differs by video, timestamp, or word', () {
      final base = NotebookRepository.buildId(
          videoId: 'v1', timestampMs: 1000, word: 'drift');
      expect(
          base,
          isNot(NotebookRepository.buildId(
              videoId: 'v2', timestampMs: 1000, word: 'drift')));
      expect(
          base,
          isNot(NotebookRepository.buildId(
              videoId: 'v1', timestampMs: 2000, word: 'drift')));
      expect(
          base,
          isNot(NotebookRepository.buildId(
              videoId: 'v1', timestampMs: 1000, word: 'wait')));
    });
  });

  group('AnalysisResult JSON', () {
    test('round-trips through toJson/fromJson', () {
      const result = AnalysisResult(
        source: 'customProvider',
        timestampMs: 4200,
        word: WordAnalysis(
          word: 'drift',
          phoneticUk: '/drɪft/',
          phoneticUs: '/drɪft/',
          partOfSpeech: 'verb',
          meaning: '漂移；漂流',
          collocations: ['drift off'],
          wordRoot: 'drift',
        ),
        sentence: SentenceAnalysis(
          sentence: 'You wait for her to drift off.',
          translation: '你等她睡着。',
          structure: ['You', 'wait', 'for her to drift off'],
          grammarNotes: ['wait for sb. to do sth.'],
          slangNotes: ['drift off = 睡着'],
          paraphrases: ['You wait until she falls asleep.'],
        ),
      );

      final restored = AnalysisResult.fromJson(result.toJson());

      expect(restored.source, result.source);
      expect(restored.timestampMs, result.timestampMs);
      expect(restored.word.word, 'drift');
      expect(restored.word.collocations, ['drift off']);
      expect(restored.sentence.translation, '你等她睡着。');
      expect(restored.sentence.structure, hasLength(3));
    });
  });
}
