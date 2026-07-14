import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_card.dart';
import '../application/notebook_controller.dart';
import '../domain/notebook_entry.dart';

class NotebookPage extends ConsumerWidget {
  const NotebookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(notebookControllerProvider);
    final controller = ref.read(notebookControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生词本'),
        actions: [
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('当前还没有收藏单词'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _NotebookCard(entry: entry),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NotebookCard extends ConsumerStatefulWidget {
  const _NotebookCard({required this.entry});

  final NotebookEntry entry;

  @override
  ConsumerState<_NotebookCard> createState() => _NotebookCardState();
}

class _NotebookCardState extends ConsumerState<_NotebookCard> {
  bool _reanalyzing = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final controller = ref.read(notebookControllerProvider.notifier);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.word,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(entry.timestampLabel),
              IconButton(
                tooltip: '删除',
                onPressed: () => controller.deleteEntry(entry.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(entry.meaning),
          const SizedBox(height: 10),
          Text(entry.sentence, style: Theme.of(context).textTheme.bodyMedium),
          if (entry.analysis.sentence.translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.analysis.sentence.translation,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _reanalyzing
                ? null
                : () async {
                    setState(() => _reanalyzing = true);
                    try {
                      await controller.reanalyze(entry);
                    } finally {
                      if (mounted) setState(() => _reanalyzing = false);
                    }
                  },
            icon: _reanalyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(_reanalyzing ? '解析中...' : '重新解析'),
          ),
        ],
      ),
    );
  }
}
