import 'package:flutter/material.dart';

import '../../core/models/document_detail_args.dart';
import '../../core/models/question_detail.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/select_document_dialog.dart';
import 'question_block_renderer.dart';

class QuestionDetailPage extends StatefulWidget {
  const QuestionDetailPage({
    required this.questionId,
    super.key,
  });

  final String questionId;

  static QuestionDetailPage fromArgs(QuestionDetailArgs args) {
    return QuestionDetailPage(questionId: args.questionId);
  }

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  late Future<_QuestionDetailViewData> _pageFuture = _loadPageData();

  Future<_QuestionDetailViewData> _loadPageData() async {
    final repository = AppServices.instance.questionRepository;
    final question = await repository.getQuestionDetail(widget.questionId);
    final basketIds = await repository.listBasketQuestionIds();
    return _QuestionDetailViewData(
      question: question,
      isInBasket: question != null && basketIds.contains(question.id),
    );
  }

  Future<void> _addToDocument(QuestionDetail question) async {
    final targetDocument = await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }
    final createdItem = await AppServices.instance.documentRepository.addQuestionToDocument(
      documentId: targetDocument.id,
      question: question.toSummary(),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已加入文档：${targetDocument.name}')),
    );
    Navigator.of(context).pushNamed(
      AppRouter.documentDetail,
      arguments: DocumentDetailArgs(
        documentId: targetDocument.id,
        focusItemId: createdItem.id,
        focusItemTitle: question.title,
      ),
    );
  }

  Future<void> _toggleBasket(QuestionDetail question, bool isInBasket) async {
    final repository = AppServices.instance.questionRepository;
    if (isInBasket) {
      await repository.removeQuestionFromBasket(question.id);
    } else {
      await repository.addQuestionToBasket(question.toSummary());
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pageFuture = _loadPageData();
    });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isInBasket ? '已从选题篮移除' : '已加入选题篮'),
        action: isInBasket
            ? null
            : SnackBarAction(
                label: '查看',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRouter.basket);
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('题目详情')),
      body: FutureBuilder<_QuestionDetailViewData>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final question = snapshot.data!.question;
          final isInBasket = snapshot.data!.isInBasket;
          if (question == null) {
            return const Center(child: Text('未找到对应题目'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(label: question.subject),
                          _MetaChip(label: question.stage),
                          _MetaChip(label: question.grade),
                          _MetaChip(label: question.textbook),
                          _MetaChip(label: question.chapter),
                          _MetaChip(label: '难度 ${question.difficulty}'),
                          for (final tag in question.tags) _MetaChip(label: '#$tag'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '题干预览',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      QuestionBlockRenderer(
                        blocks: question.stemBlocks,
                        fallbackText: question.stemText,
                      ),
                      if (question.sourceText.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          '题目出处',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          question.sourceText,
                          style: const TextStyle(
                            height: 1.6,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _addToDocument(question),
                            icon: const Icon(Icons.playlist_add_outlined),
                            label: const Text('加入指定文档'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _toggleBasket(question, isInBasket),
                            icon: Icon(
                              isInBasket
                                  ? Icons.bookmark_remove_outlined
                                  : Icons.collections_bookmark_outlined,
                            ),
                            label: Text(isInBasket ? '移出选题篮' : '加入选题篮'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppRouter.documents);
                            },
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('打开文档工作区'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '整体分析',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      DefaultTextStyle(
                        style: const TextStyle(
                          height: 1.6,
                          color: TelegramPalette.textMuted,
                        ),
                        child: QuestionBlockRenderer(
                          blocks: question.analysisBlocks,
                          fallbackText: question.analysisText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '详细题解',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      QuestionBlockRenderer(
                        blocks: question.solutionBlocks,
                        fallbackText: question.solutionText,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '点评',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      DefaultTextStyle(
                        style: const TextStyle(
                          height: 1.6,
                          color: TelegramPalette.textMuted,
                        ),
                        child: QuestionBlockRenderer(
                          blocks: question.commentaryBlocks,
                          fallbackText: question.commentaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on QuestionDetail {
  QuestionSummary toSummary() {
    return QuestionSummary(
      id: id,
      title: title,
      subject: subject,
      stage: stage,
      grade: grade,
      textbook: textbook,
      chapter: chapter,
      difficulty: difficulty,
      tags: tags,
      stemPreview: stemText,
    );
  }
}

class _QuestionDetailViewData {
  const _QuestionDetailViewData({
    required this.question,
    required this.isInBasket,
  });

  final QuestionDetail? question;
  final bool isInBasket;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
