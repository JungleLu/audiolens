enum SubtitleMode {
  english('原文'),
  chinese('纯中文'),
  bilingual('双语'),
  hidden('无字幕');

  const SubtitleMode(this.label);

  final String label;
}
