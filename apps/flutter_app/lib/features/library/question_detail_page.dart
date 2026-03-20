import 'package:flutter/material.dart';

import '../../core/models/document_detail_args.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/question_detail.dart';
import '../../core/models/question_detail_args.dart';
import '../../core/models/question_summary.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../documents/create_document_dialog.dart';
import '../documents/select_document_dialog.dart';
import '../shared/content_section.dart';
import '../shared/question_workspace_context_card.dart';
import '../shared/primary_navigation_bar.dart';
import '../shared/workspace_shell.dart';

class QuestionDetailPage extends StatefulWidget {
  const QuestionDetailPage({
    required this.questionId,
    this.preferredDocumentSnapshot,
    this.insertAfterItemId,
    this.insertAfterItemTitle,
    super.key,
  });

  final String questionId;
  final DocumentSummary? preferredDocumentSnapshot;
  final String? insertAfterItemId;
  final String? insertAfterItemTitle;

  static QuestionDetailPage fromArgs(QuestionDetailArgs args) {
    return QuestionDetailPage(
      questionId: args.questionId,
      preferredDocumentSnapshot: args.preferredDocumentSnapshot,
      insertAfterItemId: args.insertAfterItemId,
      insertAfterItemTitle: args.insertAfterItemTitle,
    );
  }

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  late Future<_QuestionDetailViewData> _pageFuture = _loadPageData();
  bool _addingToDocument = false;
  bool _creatingAndAdding = false;
  bool _updatingBasket = false;

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
    final targetDocument =
        widget.preferredDocumentSnapshot ?? await pickTargetDocument(context);
    if (targetDocument == null) {
      return;
    }
    await _completeAddToDocument(
      question: question,
      documentId: targetDocument.id,
      documentName: targetDocument.name,
      submittingSetter: (value) {
        _addingToDocument = value;
      },
    );
  }

  Future<void> _createDocumentAndAdd(QuestionDetail question) async {
    final targetDocument = await showCreateDocumentDialog(
      context,
      initialName: '${question.title} 讲义',
      initialKind: 'handout',
      title: '新建文档并加入',
    );
    if (targetDocument == null) {
      return;
    }
    await _completeAddToDocument(
      question: question,
      documentId: targetDocument.id,
      documentName: targetDocument.name,
      submittingSetter: (value) {
        _creatingAndAdding = value;
      },
    );
  }

  Future<void> _completeAddToDocument({
    required QuestionDetail question,
    required String documentId,
    required String documentName,
    required void Function(bool value) submittingSetter,
  }) async {
    setState(() {
      submittingSetter(true);
    });
    try {
      final previousItems = widget.insertAfterItemId == null ||
              documentId != widget.preferredDocumentSnapshot?.id
          ? null
          : await AppServices.instance.documentRepository.listDocumentItems(
              documentId,
            );
      final createdItem =
          await AppServices.instance.documentRepository.addQuestionToDocument(
        documentId: documentId,
        question: question.toSummary(),
      );
      if (previousItems != null) {
        final insertAfterIndex = previousItems.indexWhere(
          (item) => item.id == widget.insertAfterItemId,
        );
        if (insertAfterIndex >= 0) {
          final targetIndex = insertAfterIndex + 1;
          final moveSteps = previousItems.length - targetIndex;
          for (var i = 0; i < moveSteps; i += 1) {
            await AppServices.instance.documentRepository.moveDocumentItem(
              documentId: documentId,
              itemId: createdItem.id,
              offset: -1,
            );
          }
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            previousItems != null
                ? '已加入文档并插到当前选中项后：$documentName'
                : '已加入文档：$documentName',
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRouter.documentDetail,
        arguments: DocumentDetailArgs(
          documentId: documentId,
          focusItemId: createdItem.id,
          focusItemTitle: question.title,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          submittingSetter(false);
        });
      }
    }
  }

  Future<void> _toggleBasket(QuestionDetail question, bool isInBasket) async {
    if (_updatingBasket) {
      return;
    }
    setState(() {
      _updatingBasket = true;
    });
    final repository = AppServices.instance.questionRepository;
    try {
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新选题篮失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingBasket = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPrimaryNavigation = widget.preferredDocumentSnapshot == null &&
        widget.insertAfterItemId == null &&
        (widget.insertAfterItemTitle ?? '').isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('题目详情')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: FutureBuilder<_QuestionDetailViewData>(
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
              return workspaceConstrainedContent(
                context,
                child: ListView(
                  padding: workspacePagePadding(context),
                  children: [
                    _QuestionHeroCard(
                      question: question,
                      isInBasket: isInBasket,
                      inDocumentContext:
                          widget.preferredDocumentSnapshot != null,
                    ),
                    const SizedBox(height: 18),
                    WorkspacePanel(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wideDesktop = constraints.maxWidth >= 1120;
                          final mainContent = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ContentSection(
                                title: '题干预览',
                                blocks: question.stemBlocks,
                                fallbackText: question.stemText,
                              ),
                              if (question.sourceText.trim().isNotEmpty) ...[
                                const SizedBox(height: 20),
                                ContentSection(
                                  title: '题目出处',
                                  blocks: question.sourceBlocks,
                                  fallbackText: question.sourceText,
                                  backgroundColor: TelegramPalette.surfaceSoft,
                                ),
                              ],
                              const SizedBox(height: 24),
                              ContentSection(
                                title: '整体分析',
                                blocks: question.analysisBlocks,
                                fallbackText: question.analysisText,
                                backgroundColor: TelegramPalette.surfaceSoft,
                              ),
                              const SizedBox(height: 24),
                              ContentSection(
                                title: '详细题解',
                                blocks: question.solutionBlocks,
                                fallbackText: question.solutionText,
                              ),
                              if (question.referenceAnswerBlocks.isNotEmpty ||
                                  question.referenceAnswerText
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 24),
                                ContentSection(
                                  title: '参考答案',
                                  blocks: question.referenceAnswerBlocks,
                                  fallbackText: question.referenceAnswerText,
                                  backgroundColor:
                                      TelegramPalette.surfaceAccent,
                                ),
                              ],
                              if (question.scoringPointBlocks.isNotEmpty ||
                                  question.scoringPointsText
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 24),
                                ContentSection(
                                  title: '评分点',
                                  blocks: question.scoringPointBlocks,
                                  fallbackText: question.scoringPointsText,
                                  backgroundColor:
                                      TelegramPalette.surfaceAccent,
                                ),
                              ],
                              const SizedBox(height: 24),
                              ContentSection(
                                title: '点评',
                                blocks: question.commentaryBlocks,
                                fallbackText: question.commentaryText,
                                backgroundColor: TelegramPalette.surfaceSoft,
                              ),
                            ],
                          );
                          final actionButtons = <Widget>[
                            FilledButton.icon(
                              onPressed: _addingToDocument ||
                                      _creatingAndAdding ||
                                      _updatingBasket
                                  ? null
                                  : () => _addToDocument(question),
                              icon: _addingToDocument
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.playlist_add_outlined),
                              label: Text(
                                _addingToDocument
                                    ? '加入中…'
                                    : (widget.preferredDocumentSnapshot == null
                                        ? '加入指定文档'
                                        : '加入当前文档'),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _addingToDocument ||
                                      _creatingAndAdding ||
                                      _updatingBasket
                                  ? null
                                  : () => _createDocumentAndAdd(question),
                              icon: _creatingAndAdding
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.note_add_outlined),
                              label: Text(
                                _creatingAndAdding
                                    ? '创建并加入中…'
                                    : '新建文档并加入',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _updatingBasket ||
                                      _addingToDocument ||
                                      _creatingAndAdding
                                  ? null
                                  : () => _toggleBasket(
                                        question,
                                        isInBasket,
                                      ),
                              icon: _updatingBasket
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isInBasket
                                          ? Icons.bookmark_remove_outlined
                                          : Icons
                                              .collections_bookmark_outlined,
                                    ),
                              label: Text(
                                _updatingBasket
                                    ? '处理中…'
                                    : (isInBasket ? '移出选题篮' : '加入选题篮'),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                PrimaryNavigationBar.navigateToSection(
                                  context,
                                  PrimaryAppSection.documents,
                                );
                              },
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('打开文档工作区'),
                            ),
                          ];
                          final actionRail = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.preferredDocumentSnapshot != null) ...[
                                QuestionWorkspaceContextCard(
                                  documentName:
                                      widget.preferredDocumentSnapshot!.name,
                                  insertAfterItemTitle:
                                      widget.insertAfterItemTitle,
                                  onOpenDocument: () {
                                    Navigator.of(context).pushNamed(
                                      AppRouter.documentDetail,
                                      arguments: DocumentDetailArgs(
                                        documentId: widget
                                            .preferredDocumentSnapshot!.id,
                                        documentSnapshot:
                                            widget.preferredDocumentSnapshot,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: TelegramPalette.surfaceSoft,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: TelegramPalette.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const WorkspaceEyebrow(
                                      label: '题目操作',
                                      icon: Icons.tune_outlined,
                                    ),
                                    const SizedBox(height: 14),
                                    if (wideDesktop)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (var index = 0;
                                              index < actionButtons.length;
                                              index++) ...[
                                            actionButtons[index],
                                            if (index !=
                                                actionButtons.length - 1)
                                              const SizedBox(height: 12),
                                          ],
                                        ],
                                      )
                                    else
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: actionButtons,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                          if (!wideDesktop) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                actionRail,
                                const SizedBox(height: 20),
                                mainContent,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: mainContent),
                              const SizedBox(width: 20),
                              SizedBox(width: 392, child: actionRail),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar:
          MediaQuery.of(context).size.width < 900 && showPrimaryNavigation
              ? const PrimaryNavigationBar(
                  currentSection: PrimaryAppSection.library,
                )
              : null,
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
      previewBlocks: stemBlocks,
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
    return WorkspaceInfoPill(
      value: label,
      highlight: label.startsWith('#') || label.startsWith('难度 '),
    );
  }
}

class _QuestionHeroCard extends StatelessWidget {
  const _QuestionHeroCard({
    required this.question,
    required this.isInBasket,
    required this.inDocumentContext,
  });

  final QuestionDetail question;
  final bool isInBasket;
  final bool inDocumentContext;

  @override
  Widget build(BuildContext context) {
    final detail = inDocumentContext
        ? '当前正在确认一题是否加入当前文档。看完后可以直接补进文档，或返回继续挑题。'
        : '当前正在单独查看这道题。看完后可以加入选题篮，或直接放进文档。';
    return WorkspacePanel(
      padding: const EdgeInsets.all(24),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceEyebrow(
            label: 'Question Detail',
            icon: Icons.auto_stories_outlined,
          ),
          const SizedBox(height: 14),
          Text(
            question.title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: const TextStyle(
              height: 1.5,
              color: TelegramPalette.textMuted,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              WorkspaceMetricPill(
                label: '选题篮',
                value: isInBasket ? '已加入' : '未加入',
                highlight: isInBasket,
              ),
              WorkspaceMetricPill(
                label: '参考答案',
                value: question.referenceAnswerBlocks.isNotEmpty ||
                        question.referenceAnswerText.trim().isNotEmpty
                    ? '已提供'
                    : '未提供',
              ),
              WorkspaceMetricPill(
                label: '评分点',
                value: question.scoringPointBlocks.isNotEmpty ||
                        question.scoringPointsText.trim().isNotEmpty
                    ? '已提供'
                    : '未提供',
              ),
              WorkspaceMetricPill(
                label: '当前模式',
                value: inDocumentContext ? '确认并补题' : '查看单题',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
