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
      final lines = block.split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.length < 3) {
        continue;
      }

      final index = int.tryParse(lines.first.trim()) ?? cues.length + 1;
      final times = lines[1].split(' --> ');
      if (times.length != 2) {
        continue;
      }

      final bodyLines = lines.sublist(2);
      final english = bodyLines.isNotEmpty ? bodyLines.first.trim() : '';
      final chinese = bodyLines.length > 1 ? bodyLines.sublist(1).join(' ').trim() : '';

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
        final columns = trimmed.substring('format:'.length).split(',').map((c) => c.trim().toLowerCase()).toList();
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

      final segments = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
      final english = segments.isNotEmpty ? segments.first.trim() : '';
      final chinese = segments.length > 1 ? segments.sublist(1).join(' ').trim() : '';

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
    // Drop override tag blocks like {\pos(...)} and normalize hard line breaks.
    return raw
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
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
    final centi = secParts.length > 1 ? (int.tryParse(secParts[1].padRight(2, '0').substring(0, 2)) ?? 0) : 0;
    return ((((hour * 60) + minute) * 60) + second) * 1000 + centi * 10;
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
