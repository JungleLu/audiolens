class SubtitleToken {
  const SubtitleToken({required this.text, required this.isWord, required this.start, required this.end});

  final String text;
  final bool isWord;
  final int start;
  final int end;
}

class SubtitleCue {
  const SubtitleCue({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.english,
    required this.chinese,
    required this.tokens,
  });

  final int index;
  final int startMs;
  final int endMs;
  final String english;
  final String chinese;
  final List<SubtitleToken> tokens;
}
