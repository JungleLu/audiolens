import '../domain/subtitle_cue.dart';

class SubtitleParser {
  const SubtitleParser();

  List<SubtitleCue> parse(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    if (_looksLikeAss(normalized)) {
      return _parseAss(normalized);
    }
    return _parseSrt(normalized);
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
      if (lines.length < 3) {
        continue;
      }

      final index = int.tryParse(lines.first.trim()) ?? cues.length + 1;
      final times = lines[1].split(' --> ');
      if (times.length != 2) {
        continue;
      }

      final bodyLines = lines.sublist(2);
      final (english, chinese) = _splitLanguages(bodyLines);

      cues.add(
        SubtitleCue(
          index: index,
          startMs: _parseSrtTime(times[0]),
          endMs: _parseSrtTime(times[1]),
          english: english,
          chinese: chinese,
          tokens: _tokenize(english),
        ),
      );
    }

    return cues;
  }

  List<SubtitleCue> _parseAss(String content) {
    final lines = content.split('\n');
    final cues = <SubtitleCue>[];
    var inEvents = false;
    var startField = 1;
    var endField = 2;
    var textField = 9;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        inEvents = trimmed.toLowerCase() == '[events]';
        continue;
      }
      if (!inEvents) {
        continue;
      }

      if (trimmed.toLowerCase().startsWith('format:')) {
        final columns = trimmed
            .substring('format:'.length)
            .split(',')
            .map((c) => c.trim().toLowerCase())
            .toList();
        final startIndex = columns.indexOf('start');
        final endIndex = columns.indexOf('end');
        final textIndex = columns.indexOf('text');
        if (startIndex != -1) startField = startIndex;
        if (endIndex != -1) endField = endIndex;
        if (textIndex != -1) textField = textIndex;
        continue;
      }

      if (!trimmed.toLowerCase().startsWith('dialogue:')) {
        continue;
      }

      // Split into exactly textField+1 parts so the Text field keeps its commas.
      final fields = trimmed.substring('dialogue:'.length).split(',');
      if (fields.length <= textField) {
        continue;
      }
      final rawText = fields.sublist(textField).join(',');
      final text = _cleanAssText(rawText);
      if (text.isEmpty) {
        continue;
      }

      final segments =
          text.split('\n').where((s) => s.trim().isNotEmpty).toList();
      final (english, chinese) = _splitLanguages(segments);

      cues.add(
        SubtitleCue(
          index: cues.length + 1,
          startMs: _parseAssTime(fields[startField]),
          endMs: _parseAssTime(fields[endField]),
          english: english,
          chinese: chinese,
          tokens: _tokenize(english),
        ),
      );
    }

    return cues;
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
        // Unterminated block — treat the rest as-is (outside drawing) and stop.
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
    if (parts.length != 4) {
      return 0;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = int.tryParse(parts[2]) ?? 0;
    final milli = int.tryParse(parts[3]) ?? 0;
    return ((((hour * 60) + minute) * 60) + second) * 1000 + milli;
  }

  int _parseAssTime(String raw) {
    // ASS time format: H:MM:SS.cc (centiseconds).
    final parts = raw.trim().split(':');
    if (parts.length != 3) {
      return 0;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final second = int.tryParse(secParts[0]) ?? 0;
    final centi = secParts.length > 1
        ? (int.tryParse(secParts[1].padRight(2, '0').substring(0, 2)) ?? 0)
        : 0;
    return ((((hour * 60) + minute) * 60) + second) * 1000 + centi * 10;
  }

  /// Split bilingual subtitle body lines into (english, chinese) by content
  /// rather than position — files vary in ordering (English-first vs
  /// Chinese-first), so classify each line by whether it contains CJK.
  (String, String) _splitLanguages(List<String> lines) {
    final english = <String>[];
    final chinese = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      if (_hasCjk(line)) {
        chinese.add(line);
      } else {
        english.add(line);
      }
    }
    return (english.join(' ').trim(), chinese.join(' ').trim());
  }

  bool _hasCjk(String text) {
    return RegExp(r'[一-鿿㐀-䶿豈-﫿]').hasMatch(text);
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
