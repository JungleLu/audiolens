class SubtitleToken {
  const SubtitleToken(
      {required this.text,
      required this.isWord,
      required this.start,
      required this.end});

  final String text;
  final bool isWord;
  final int start;
  final int end;
}

enum SubtitleKind { dialogue, lyric, watermark }

class SubtitleCue {
  const SubtitleCue({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.english,
    required this.chinese,
    required this.tokens,
    this.kind = SubtitleKind.dialogue,
  });

  final int index;
  final int startMs;
  final int endMs;
  final String english;
  final String chinese;
  final List<SubtitleToken> tokens;
  final SubtitleKind kind;

  /// The non-Chinese line when the subtitle is bilingual; otherwise whichever
  /// single language the file provides.
  String get original => english.isNotEmpty ? english : chinese;
}
