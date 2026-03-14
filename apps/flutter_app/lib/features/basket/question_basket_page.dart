import 'package:flutter/material.dart';

import '../../core/models/document_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../documents/select_document_dialog.dart';
import '../../router/app_router.dart';

class QuestionBasketPage extends StatefulWidget {
  const QuestionBasketPage({super.key});

  @override
  State<QuestionBasketPage> createState() => _QuestionBasketPageState();
}

class _QuestionBasketPageState extends State<QuestionBasketPage> {
  List<QuestionSummary>? _questions;

  @override
  void initState() {
    super.initState();
    _loadBasket();
  }

  Future<void> _loadBasket() async {
    final questions = await AppServices.instance.questionRepository.listBasketQuestions();
    if (!mounted) {
      return;
    }
    setState(() {
      _questions = questions;
    });
  }

  Future<void> _addAllToDocument() async {
    final questions = _questions ?? const <QuestionSummary>[];
    if (questions.isEmpty) {
      return;
    }

    final targetDocument = await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }

    final clearAfterAdd = await _pickBulkAddFollowUp(questions.length);
    if (clearAfterAdd == null) {
      return;
    }

    final createdItems = await AppServices.instance.documentRepository.addQuestionsToDocument(
      documentId: targetDocument.id,
      questions: questions,
    );
    if (!mounted) {
      return;
    }

    if (clearAfterAdd) {
      await AppServices.instance.questionRepository.clearBasket();
      if (!mounted) {
        return;
      }
      setState(() {
        _questions = <QuestionSummary>[];
      });
    }

    final focusItem = createdItems.isNotEmpty ? createdItems.last : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          clearAfterAdd
              ? '已将 ${questions.length} 道题加入文档并清空选题篮：${targetDocument.name}'
              : '已将 ${questions.length} 道题加入文档：${targetDocument.name}',
        ),
      ),
    );
    Navigator.of(context).pushNamed(
      AppRouter.documentDetail,
      arguments: DocumentDetailArgs(
        documentId: targetDocument.id,
        focusItemId: focusItem?.id,
        focusItemTitle: focusItem?.title ?? questions.last.title,
        recentlyAddedQuestionCount: questions.length,
      ),
    );
  }

  Future<bool?> _pickBulkAddFollowUp(int questionCount) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('批量加入文档'),
        content: Text(
          '即将把 $questionCount 道题加入目标文档。加入后是否同时清空当前选题篮？',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('加入但保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('加入并清空'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeQuestion(QuestionSummary question) async {
    await AppServices.instance.questionRepository.removeQuestionFromBasket(question.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _questions = (_questions ?? <QuestionSummary>[])
          .where((item) => item.id != question.id)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已从选题篮移除：${question.title}')),
    );
  }

  Future<void> _clearBasket() async {
    await AppServices.instance.questionRepository.clearBasket();
    if (!mounted) {
      return;
    }
    setState(() {
      _questions = <QuestionSummary>[];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('选题篮已清空')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选题篮')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                spacing: 12,
                children: [
                  const SizedBox(
                    width: 420,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前选题工作区',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '这里会承接移动端和桌面端的“先找题、再组题、再编讲义/试卷”流程。当前先用本地数据模拟。',
                          style: TextStyle(
                            height: 1.5,
                            color: TelegramPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.documents);
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('进入文档工作区'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.library);
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('继续挑题'),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_questions == null || _questions!.isEmpty) ? null : _clearBasket,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清空选题篮'),
                  ),
                  FilledButton.icon(
                    onPressed: (_questions == null || _questions!.isEmpty)
                        ? null
                        : _addAllToDocument,
                    icon: const Icon(Icons.playlist_add_check_circle_outlined),
                    label: const Text('全部加入文档'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_questions == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_questions!.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前选题篮为空。你可以先从题库挑题，再回到这里继续编排文档。',
                      style: TextStyle(height: 1.5, color: TelegramPalette.textMuted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.library);
                      },
                      icon: const Icon(Icons.travel_explore_outlined),
                      label: const Text('去题库挑题'),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _questions!
                  .map(
                    (question) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BasketQuestionCard(
                        question: question,
                        onRemove: () => _removeQuestion(question),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _BasketQuestionCard extends StatelessWidget {
  const _BasketQuestionCard({
    required this.question,
    required this.onRemove,
  });

  final QuestionSummary question;
  final Future<void> Function() onRemove;

  Future<void> _addToDocument(BuildContext context) async {
    final targetDocument = await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }
    final createdItem = await AppServices.instance.documentRepository.addQuestionToDocument(
      documentId: targetDocument.id,
      question: question,
    );
    if (!context.mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${question.grade} · ${question.textbook} · ${question.chapter}',
              style: const TextStyle(color: TelegramPalette.textSoft),
            ),
            const SizedBox(height: 10),
            Text(question.stemPreview, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _addToDocument(context),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('加入文档'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onRemove(),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('移出选题篮'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
