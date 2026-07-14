import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../ai/domain/analysis_models.dart';
import '../../application/player_controller.dart';

class AnalysisBottomSheet extends ConsumerWidget {
  const AnalysisBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final analysis = session.analysis;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (session.isAnalyzing) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                'AI 正在解析字幕内容...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else if (analysis != null) ...[
              _AnalysisView(analysis: analysis, isSentence: session.selectedWord == null),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await controller.saveCurrentAnalysis();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('加入生词本'),
                ),
              ),
            ] else ...[
              Text(
                '尚未生成解析',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('点击字幕中的单词或整句后，这里会展示统一结构的解析结果。'),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalysisView extends StatelessWidget {
  const _AnalysisView({required this.analysis, required this.isSentence});

  final AnalysisResult analysis;
  final bool isSentence;

  @override
  Widget build(BuildContext context) {
    return isSentence ? _buildSentenceView(context) : _buildWordView(context);
  }

  Widget _buildSentenceView(BuildContext context) {
    final s = analysis.sentence;
    final w = analysis.word;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.sentence,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          s.translation,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.sea),
        ),
        const SizedBox(height: 18),
        _block(
          context,
          title: '语法分析',
          body:
              '结构拆分：${s.structure.join(' + ')}\n语法点：${s.grammarNotes.join('；')}\n俚语拓展：${s.slangNotes.join('；')}',
        ),
        if (s.paraphrases.isNotEmpty) ...[
          const SizedBox(height: 14),
          _block(context, title: '同义改写', body: s.paraphrases.join('\n')),
        ],
        const SizedBox(height: 14),
        _block(
          context,
          title: '重点单词',
          body:
              '${w.word}${w.partOfSpeech.isEmpty ? '' : '（${w.partOfSpeech}）'}\n释义：${w.meaning}\n搭配：${w.collocations.join(' / ')}',
        ),
      ],
    );
  }

  Widget _buildWordView(BuildContext context) {
    final w = analysis.word;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          w.word,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '英 ${w.phoneticUk}   ·   美 ${w.phoneticUs}   ·   ${w.partOfSpeech}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.sea),
        ),
        const SizedBox(height: 18),
        _block(
          context,
          title: '单词区',
          body: '释义：${w.meaning}\n搭配：${w.collocations.join(' / ')}\n词根词缀：${w.wordRoot}',
        ),
        const SizedBox(height: 14),
        _block(
          context,
          title: '整句区',
          body:
              '通顺翻译：${analysis.sentence.translation}\n结构拆分：${analysis.sentence.structure.join(' + ')}\n语法点：${analysis.sentence.grammarNotes.join('；')}\n俚语拓展：${analysis.sentence.slangNotes.join('；')}\n同义改写：${analysis.sentence.paraphrases.join(' / ')}',
        ),
      ],
    );
  }

  Widget _block(BuildContext context, {required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
