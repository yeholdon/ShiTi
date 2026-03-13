import 'package:flutter/material.dart';

import '../../core/models/document_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/services/app_services.dart';
import '../documents/select_document_dialog.dart';
import '../../router/app_router.dart';

class QuestionBasketPage extends StatefulWidget {
  const QuestionBasketPage({super.key});

  @override
  State<QuestionBasketPage> createState() => _QuestionBasketPageState();
}

class _QuestionBasketPageState extends State<QuestionBasketPage> {
  late final Future<List<QuestionSummary>> _basketFuture =
      AppServices.instance.questionRepository.listBasketQuestions();

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
                            color: Color(0xFF4C6964),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<QuestionSummary>>(
            future: _basketFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final questions = snapshot.data!;
              return Column(
                children: questions
                    .map(
                      (question) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BasketQuestionCard(question: question),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BasketQuestionCard extends StatelessWidget {
  const _BasketQuestionCard({required this.question});

  final QuestionSummary question;

  Future<void> _addToDocument(BuildContext context) async {
    final targetDocument = await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }
    await AppServices.instance.documentRepository.addQuestionToDocument(
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
      arguments: DocumentDetailArgs(documentId: targetDocument.id),
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
              style: const TextStyle(color: Color(0xFF52726D)),
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
                  onPressed: () {},
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
