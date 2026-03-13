import 'package:flutter/material.dart';

import '../../core/models/document_detail_args.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/services/app_services.dart';
import '../documents/select_document_dialog.dart';
import '../../router/app_router.dart';

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
  late final Future<QuestionSummary?> _questionFuture =
      AppServices.instance.questionRepository.getQuestion(widget.questionId);

  Future<void> _addToDocument(QuestionSummary question) async {
    final targetDocument = await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }
    await AppServices.instance.documentRepository.addQuestionToDocument(
      documentId: targetDocument.id,
      question: question,
    );
    if (!mounted) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('题目详情')),
      body: FutureBuilder<QuestionSummary?>(
        future: _questionFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final question = snapshot.data;
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
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '题干预览',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        question.stemPreview,
                        style: const TextStyle(height: 1.6),
                      ),
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
                        '题解结构',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '这里预留给 block / LaTeX 详情渲染。下一步直接接 questions detail API，就可以在移动端、网页端、桌面端共用同一套详情组件。',
                        style: TextStyle(height: 1.6, color: Color(0xFF4C6964)),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}
