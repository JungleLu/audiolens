import '../domain/subtitle_cue.dart';

class SubtitleParser {
  const SubtitleParser();

  // Matches common subtitle-group watermark signatures.
  static final _watermarkPattern = RegExp(
    r'YYeTs|人人影视|蓝光转压|双语字幕|本字幕(来源|由)|后期\s|校对\s|翻译\s|时间轴|www\.|\.com|招(募|新)|微博',
    caseSensitive: false,
  );

  // ASS style names that indicate non-dialogue (lyrics / credits / watermark).
  static final _lyricStylePattern = RegExp(
    r'^(op|ed|song|op&ed|opening|ending|staff|title|karaoke|kara|sign)',
    caseSensitive: false,
  );
  static final _watermarkStylePattern = RegExp(
    r'^(staff|credit|watermark|info)',
    caseSensitive: false,
  );

  List<SubtitleCue> parse(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final all = _looksLikeAss(normalized)
        ? _parseAss(normalized)
        : _parseSrt(normalized);
    // Filter to dialogue only; re-number index for consumers that rely on it.
    final dialogues =
        all.where((c) => c.kind == SubtitleKind.dialogue).toList();
    return [
      for (var i = 0; i < dialogues.length; i++)
        SubtitleCue(
          index: i + 1,
          startMs: dialogues[i].startMs,
          endMs: dialogues[i].endMs,
          english: dialogues[i].english,
          chinese: dialogues[i].chinese,
          tokens: dialogues[i].tokens,
          kind: SubtitleKind.dialogue,
        ),
    ];
  }

  bool _looksLikeAss(String content) {
    return content.contains('[Events]') || content.contains('[Script Info]');
  }

  List<SubtitleCue> _parseSrt(String content) {
    final blocks = content.split('\n\n');
    final cues = <SubtitleCue>[];

    for (final block in blocks) {
      final lines =
          block.split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.length < 3) continue;

      final index = int.tryParse(lines.first.trim()) ?? cues.length + 1;
      final times = lines[1].split(' --> ');
      if (times.length != 2) continue;

      final bodyLines = lines.sublist(2);
      final (english, chinese) = _splitLanguages(bodyLines);
      final combined = '$english $chinese';
      final kind = _watermarkPattern.hasMatch(combined)
          ? SubtitleKind.watermark
          : SubtitleKind.dialogue;

      cues.add(SubtitleCue(
        index: index,
        startMs: _parseSrtTime(times[0]),
        endMs: _parseSrtTime(times[1]),
        english: english,
        chinese: chinese,
        tokens: _tokenize(english),
        kind: kind,
      ));
    }

    return cues;
  }

  List<SubtitleCue> _parseAss(String content) {
    final lines = content.split('\n');
    final cues = <SubtitleCue>[];
    var inEvents = false;
    var startField = 1;
    var endField = 2;
    var styleField = 3;
    var textField = 9;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        inEvents = trimmed.toLowerCase() == '[events]';
        continue;
      }
      if (!inEvents) continue;

      if (trimmed.toLowerCase().startsWith('format:')) {
        final columns = trimmed
            .substring('format:'.length)
            .split(',')
            .map((c) => c.trim().toLowerCase())
            .toList();
        final startIndex = columns.indexOf('start');
        final endIndex = columns.indexOf('end');
        final styleIndex = columns.indexOf('style');
        final textIndex = columns.indexOf('text');
        if (startIndex != -1) startField = startIndex;
        if (endIndex != -1) endField = endIndex;
        if (styleIndex != -1) styleField = styleIndex;
        if (textIndex != -1) textField = textIndex;
        continue;
      }

      if (!trimmed.toLowerCase().startsWith('dialogue:')) continue;

      final fields = trimmed.substring('dialogue:'.length).split(',');
      if (fields.length <= textField) continue;

      final rawText = fields.sublist(textField).join(',');
      final styleName =
          styleField < fields.length ? fields[styleField].trim() : '';

      final kind = _classifyAss(rawText, styleName);

      // For drawing-only lines the text will be empty after cleaning — the
      // existing empty-check below handles that, but we still want to classify
      // them so they don't sneak through if cleaning ever changes.
      final text = _cleanAssText(rawText);
      if (text.isEmpty) continue;

      final segments =
          text.split('\n').where((s) => s.trim().isNotEmpty).toList();
      final (english, chinese) = _splitLanguages(segments);

      cues.add(SubtitleCue(
        index: cues.length + 1,
        startMs: _parseAssTime(fields[startField]),
        endMs: _parseAssTime(fields[endField]),
        english: english,
        chinese: chinese,
        tokens: _tokenize(english),
        kind: kind,
      ));
    }

    return cues;
  }

  SubtitleKind _classifyAss(String rawText, String styleName) {
    // 1. Style name — most authoritative signal.
    if (_lyricStylePattern.hasMatch(styleName)) return SubtitleKind.lyric;
    if (_watermarkStylePattern.hasMatch(styleName)) return SubtitleKind.watermark;

    // 2. Italic marker on the English/romaji segment — subtitle groups
    //    conventionally mark song lyrics with \i1 inside the tag block of the
    //    non-CJK line while leaving dialogue plain.
    //    We check the raw (uncleaned) text so the tag is still present.
    if (_hasItalicEnglishSegment(rawText)) return SubtitleKind.lyric;

    // 3. Watermark text in the cleaned content.
    final cleaned = _cleanAssText(rawText)
        .replaceAll(RegExp(r'\\[Nn]'), ' ')
        .trim();
    if (_watermarkPattern.hasMatch(cleaned)) return SubtitleKind.watermark;

    // 4. Decorative title/sign card: an oversized, positioned caption. Spoken
    //    dialogue bodies use small fonts (~14–16) and are not \pos/\an-anchored;
    //    title cards and signs use a large font AND explicit placement. Require
    //    both so centered/emphasized real dialogue isn't caught.
    if (_isOversizedPositioned(rawText)) return SubtitleKind.watermark;

    return SubtitleKind.dialogue;
  }

  /// True when a tag block carries an explicit position/anchor AND an oversized
  /// primary font. Title cards ("老友记 第三季第一集") and on-screen signs use
  /// large positioned text; spoken dialogue does not. Both conditions are
  /// required so an emphasized-but-normal line of dialogue isn't misclassified.
  bool _isOversizedPositioned(String rawText) {
    // Only inspect the first tag block — the primary font of the segment.
    final firstBlock = RegExp(r'\{([^}]*)\}').firstMatch(rawText)?.group(1);
    if (firstBlock == null) return false;
    final positioned = RegExp(r'\\(pos|move|an\d)').hasMatch(firstBlock);
    if (!positioned) return false;
    final fsMatch = RegExp(r'\\fs(\d+(?:\.\d+)?)').firstMatch(firstBlock);
    if (fsMatch == null) return false;
    final size = double.tryParse(fsMatch.group(1)!) ?? 0;
    return size >= 24;
  }

  /// Returns true when the raw ASS text has a non-CJK segment whose tag block
  /// contains \i1 (italic on) but not a matching \i0 before the text starts —
  /// the canonical signal for song lyrics in bilingual subtitle files.
  bool _hasItalicEnglishSegment(String rawText) {
    // Split on \N / \n (ASS line break tags, before cleaning).
    final segments = rawText.split(RegExp(r'\\[Nn]'));
    for (final seg in segments) {
      // Collect all {...} blocks preceding the visible text in this segment.
      final tagContent = StringBuffer();
      var i = 0;
      while (i < seg.length) {
        final open = seg.indexOf('{', i);
        if (open == -1) break;
        final close = seg.indexOf('}', open);
        if (close == -1) break;
        tagContent.write(seg.substring(open + 1, close));
        i = close + 1;
      }
      final tags = tagContent.toString();
      // Visible text outside tag blocks.
      final visible = seg.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
      if (visible.isEmpty) continue;
      // Only apply the italic heuristic to non-CJK segments (English/romaji).
      if (_hasCjk(visible)) continue;
      // \i1 present and not immediately cancelled by \i0 in the same block.
      if (RegExp(r'\\i1').hasMatch(tags) && !RegExp(r'\\i0').hasMatch(tags)) {
        return true;
      }
    }
    return false;
  }

  String _cleanAssText(String raw) {
    // ASS text is interleaved with {...} override blocks. A {\p<n>} tag with
    // n>=1 switches into vector-drawing mode, where the "text" between blocks is
    // path coordinates (m/l/b commands) rather than words; {\p0} switches back.
    // Walk the string, tracking drawing state, and keep only real text runs.
    final buffer = StringBuffer();
    var drawing = false;
    var i = 0;
    while (i < raw.length) {
      final open = raw.indexOf('{', i);
      if (open == -1) {
        if (!drawing) buffer.write(raw.substring(i));
        break;
      }
      if (!drawing) buffer.write(raw.substring(i, open));

      final close = raw.indexOf('}', open);
      if (close == -1) {
        if (!drawing) buffer.write(raw.substring(open));
        break;
      }
      final block = raw.substring(open + 1, close);
      final drawMatch = RegExp(r'\\p(\d+)').allMatches(block).lastOrNull;
      if (drawMatch != null) {
        drawing = (int.tryParse(drawMatch.group(1)!) ?? 0) >= 1;
      }
      i = close + 1;
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'\\[Nn]'), '\n')
        .replaceAll(RegExp(r'\\h'), ' ')
        .trim();
  }

  int _parseSrtTime(String raw) {
    final parts = raw.trim().split(RegExp('[:,]'));
    if (parts.length != 4) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = int.tryParse(parts[2]) ?? 0;
    final milli = int.tryParse(parts[3]) ?? 0;
    return ((((hour * 60) + minute) * 60) + second) * 1000 + milli;
  }

  int _parseAssTime(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 3) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final second = int.tryParse(secParts[0]) ?? 0;
    final centi = secParts.length > 1
        ? (int.tryParse(secParts[1].padRight(2, '0').substring(0, 2)) ?? 0)
        : 0;
    return ((((hour * 60) + minute) * 60) + second) * 1000 + centi * 10;
  }

  (String, String) _splitLanguages(List<String> lines) {
    final english = <String>[];
    final chinese = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (_hasCjk(line)) {
        chinese.add(line);
      } else {
        english.add(line);
      }
    }
    return (english.join(' ').trim(), chinese.join(' ').trim());
  }

  bool _hasCjk(String text) {
    return RegExp(r'[一-鿿㐀-䶿豈-﫿]').hasMatch(text);
  }

  List<SubtitleToken> _tokenize(String line) {
    final matches = RegExp(r"[A-Za-z']+|[^A-Za-z']+").allMatches(line);
    return matches
        .map(
          (match) => SubtitleToken(
            text: match.group(0) ?? '',
            isWord: RegExp(r"[A-Za-z']+").hasMatch(match.group(0) ?? ''),
            start: match.start,
            end: match.end,
          ),
        )
        .toList();
  }
}
