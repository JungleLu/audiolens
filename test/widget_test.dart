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

    test('filters ASS theme-song lyrics, watermarks and title cards', () {
      const ass = '''
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:22:07.46,0:22:08.93,*Default,NTP,0000,0000,0000,,怎么了  甜心  有什么问题\\N{\\fn微软雅黑\\fs14}What? Honey,what is it?
Dialogue: 0,0:22:08.93,0:22:10.76,*Default,NTP,0000,0000,0000,,我的发型不对吗\\N{\\fn微软雅黑\\fs14}Did I get wrong, did I get the hair wrong?
Dialogue: 0,0:22:10.84,0:22:11.51,*Default,NTP,0000,0000,0000,,还是别的问题  \\N{\\fn微软雅黑\\fs14}Or what?
Dialogue: 0,0:22:11.51,0:22:13.37,*Default,NTP,0000,0000,0000,,跟你想像得不同  怎么回事\\N{\\fn微软雅黑\\fs14}Did you just picture it differently? What, what?
Dialogue: 0,0:22:13.40,0:22:16.49,*Default,NTP,0000,0000,0000,,不不  不是你的问题  是...\\N{\\fn微软雅黑\\fs14}No, no. It's not you. It's, it's....
Dialogue: 0,0:22:22.14,0:22:25.83,*Default,NTP,0000,0000,0000,,怎么了  拜托  甜心  你把我吓坏了\\N{\\fn微软雅黑\\fs14}What is it? Come on, sweetie. You're,like,freaking me out here.
Dialogue: 0,0:22:28.63,0:22:31.55,*Default,NTP,0000,0000,0000,,我恨钱德勒  那个混蛋毁了我的人生\\N{\\fn微软雅黑\\fs14}I hate Chandler. The bastard ruined my life!
Dialogue: 0,0:00:22.64,0:00:24.92,*Default,NTP,0000,0000,0000,,{\\fad(500,0)\\fn手写大象体\\b1\\fs43\\pos(187.945,207.436)}老友记\\N{\\fs16}第三季第一集
Dialogue: 0,0:00:27.71,0:00:32.89,*Default,NTP,0000,0000,0000,,{\\an3\\fn方正宋刻本秀楷简体\\shad0\\bord0}没人告诉你生活会是这样\\N{\\fn微软雅黑\\fs14\\i1}So no one told you life was gonna be this way
Dialogue: 0,0:00:32.89,0:00:35.01,*Default,NTP,0000,0000,0000,,{\\an3\\fn方正宋刻本秀楷简体\\shad0\\bord0}你滑稽的工作  你的差劲\\N{\\fn微软雅黑\\fs14\\i1}your jobs a joke, you're broke,
Dialogue: 0,0:01:01.46,0:01:04.47,*Default,NTP,0000,0000,0000,,{\\an3\\fn方正宋刻本秀楷简体\\shad0\\bord0}因为你也陪伴着我\\N{\\fn微软雅黑\\fs14\\i1}'cause you're there for me too.
Dialogue: 0,0:01:07.46,0:01:11.96,*Default,NTP,0000,0000,0000,,{\\fad(0,500)\\fs16\\bord0\\shad0\\blur5\\t(0,500,\\blur0)\\b1\\c&HECB000&\\pos(99,242)}蓝光转压 双语字幕
Dialogue: 0,0:01:07.46,0:01:11.96,*Default,NTP,0000,0000,0000,,{\\fad(0,500)\\fn方正准圆_GBK\\b1\\bord0\\shad0\\fs17\\pos(235.108,242)\\K40}本字幕来源网络\\N{\\K40}后期  吉吉\\N{\\fs18}{\\fn方正综艺_GBK\\c&H26F4FF&}{\\K40}www.YYeTs.com
''';
      final cues = parser.parse(ass);

      // Only the 7 real dialogue lines (0:22:07–0:22:31) survive.
      expect(cues, hasLength(7));
      expect(cues.first.english, 'What? Honey,what is it?');
      expect(cues.first.chinese, '怎么了  甜心  有什么问题');
      expect(cues.last.english, 'I hate Chandler. The bastard ruined my life!');
      // Index is re-numbered contiguously after filtering.
      expect(cues.map((c) => c.index), [1, 2, 3, 4, 5, 6, 7]);
      // No lyric, title card or watermark leaked through.
      final joined = cues.map((c) => '${c.english} ${c.chinese}').join(' ');
      expect(joined.contains('no one told you'), isFalse);
      expect(joined.contains('老友记'), isFalse);
      expect(joined.contains('YYeTs'), isFalse);
      expect(joined.contains('双语字幕'), isFalse);
    });

    test('filters SRT watermark line by text', () {
      const srt = '''
1
00:00:01,000 --> 00:00:03,500
Hello there!
你好！

2
00:05:00,000 --> 00:05:03,000
www.YYeTs.com
人人影视
''';
      final cues = parser.parse(srt);

      expect(cues, hasLength(1));
      expect(cues.single.english, 'Hello there!');
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
