import 'package:flutter/material.dart';

import '../../core/models/document_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../shared/workspace_shell.dart';
import 'create_document_dialog.dart';
import 'document_summary_preview.dart';

Future<DocumentSummary?> pickTargetDocument(
  BuildContext context, {
  Set<String> excludedDocumentIds = const {},
}) {
  return showDialog<DocumentSummary>(
    context: context,
    builder: (_) => _SelectDocumentDialog(
      excludedDocumentIds: excludedDocumentIds,
    ),
  );
}

class _SelectDocumentDialog extends StatefulWidget {
  const _SelectDocumentDialog({
    required this.excludedDocumentIds,
  });

  final Set<String> excludedDocumentIds;

  @override
  State<_SelectDocumentDialog> createState() => _SelectDocumentDialogState();
}

class _SelectDocumentDialogState extends State<_SelectDocumentDialog> {
  late Future<List<DocumentSummary>> _documentsFuture =
      AppServices.instance.documentRepository.listDocuments();
  final TextEditingController _queryController = TextEditingController();
  String _query = '';
  String _kindFilter = 'all';
  String _exportStatusFilter = 'all';
  String _sortBy = 'list';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _documentsFuture =
          AppServices.instance.documentRepository.listDocuments();
    });
  }

  List<DocumentSummary> _applyFilter(List<DocumentSummary> documents) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = documents.where((document) {
      if (widget.excludedDocumentIds.contains(document.id)) {
        return false;
      }
      if (_kindFilter != 'all' && document.kind != _kindFilter) {
        return false;
      }
      if (_exportStatusFilter != 'all' &&
          document.latestExportStatus != _exportStatusFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return <String>[
        document.name,
        document.kind,
        document.latestExportStatus,
      ].any((value) => value.toLowerCase().contains(normalizedQuery));
    }).toList(growable: false);
    return _applySort(filtered);
  }

  List<DocumentSummary> _applySort(List<DocumentSummary> documents) {
    final sorted = documents.toList(growable: true);
    switch (_sortBy) {
      case 'name':
        sorted.sort(
          (left, right) => left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              ),
        );
        break;
      case 'kind':
        sorted.sort((left, right) {
          final compare = left.kind.compareTo(right.kind);
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              );
        });
        break;
      case 'export_status':
        sorted.sort((left, right) {
          final compare = _exportStatusRank(left.latestExportStatus).compareTo(
            _exportStatusRank(right.latestExportStatus),
          );
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              );
        });
        break;
      case 'question_count':
        sorted.sort((left, right) {
          final compare = right.questionCount.compareTo(left.questionCount);
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              );
        });
        break;
      case 'layout_count':
        sorted.sort((left, right) {
          final compare = right.layoutCount.compareTo(left.layoutCount);
          if (compare != 0) {
            return compare;
          }
          return left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              );
        });
        break;
      case 'list':
      default:
        break;
    }
    return sorted;
  }

  int _exportStatusRank(String status) {
    switch (status) {
      case 'failed':
        return 0;
      case 'running':
        return 1;
      case 'pending':
        return 2;
      case 'not_started':
        return 3;
      case 'canceled':
        return 4;
      case 'succeeded':
        return 5;
      default:
        return 6;
    }
  }

  List<(String, String)> get _activeFilterEntries {
    final entries = <(String, String)>[];
    final normalizedQuery = _query.trim();
    if (normalizedQuery.isNotEmpty) {
      entries.add(('关键词', normalizedQuery));
    }
    if (_kindFilter == 'handout') {
      entries.add(('文档类型', '讲义'));
    } else if (_kindFilter == 'paper') {
      entries.add(('文档类型', '试卷'));
    }
    if (_exportStatusFilter != 'all') {
      entries.add(('导出状态', _exportStatusLabel(_exportStatusFilter)));
    }
    if (_sortBy != 'list') {
      entries.add(('排序', _sortLabel(_sortBy)));
    }
    if (widget.excludedDocumentIds.isNotEmpty) {
      entries.add(('排除目标', '${widget.excludedDocumentIds.length} 份'));
    }
    return entries;
  }

  String _exportStatusLabel(String value) {
    switch (value) {
      case 'not_started':
        return '未导出';
      case 'pending':
        return '待处理';
      case 'running':
        return '处理中';
      case 'succeeded':
        return '已完成';
      case 'failed':
        return '失败';
      case 'canceled':
        return '已取消';
      case 'all':
      default:
        return '全部状态';
    }
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'name':
        return '按名称';
      case 'kind':
        return '按类型';
      case 'question_count':
        return '题目数优先';
      case 'layout_count':
        return '排版项优先';
      case 'export_status':
        return '按导出状态';
      case 'list':
      default:
        return '列表顺序';
    }
  }

  Future<void> _createDocument() async {
    final created = await showCreateDocumentDialog(context);
    if (created == null || !mounted) {
      return;
    }
    _reload();
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: WorkspacePanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择目标文档',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '从现有文档里选择承接目标，或直接新建一份文档继续加入题目。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _queryController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: '搜索目标文档',
                  hintText: '文档名称 / 类型 / 导出状态',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _queryController.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close),
                          tooltip: '清空搜索',
                        ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final controls = <Widget>[
                    SizedBox(
                      width: compact ? double.infinity : 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: _kindFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '文档类型',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部类型')),
                          DropdownMenuItem(value: 'handout', child: Text('讲义')),
                          DropdownMenuItem(value: 'paper', child: Text('试卷')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _kindFilter = value;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: _exportStatusFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '导出状态',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('全部状态')),
                          DropdownMenuItem(
                            value: 'not_started',
                            child: Text('未导出'),
                          ),
                          DropdownMenuItem(
                              value: 'pending', child: Text('待处理')),
                          DropdownMenuItem(
                              value: 'running', child: Text('处理中')),
                          DropdownMenuItem(
                            value: 'succeeded',
                            child: Text('已完成'),
                          ),
                          DropdownMenuItem(value: 'failed', child: Text('失败')),
                          DropdownMenuItem(
                              value: 'canceled', child: Text('已取消')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _exportStatusFilter = value;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: _sortBy,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '排序',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'list', child: Text('列表顺序')),
                          DropdownMenuItem(value: 'name', child: Text('按名称')),
                          DropdownMenuItem(value: 'kind', child: Text('按类型')),
                          DropdownMenuItem(
                            value: 'question_count',
                            child: Text('题目数优先'),
                          ),
                          DropdownMenuItem(
                            value: 'layout_count',
                            child: Text('排版项优先'),
                          ),
                          DropdownMenuItem(
                            value: 'export_status',
                            child: Text('按导出状态'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
                        },
                      ),
                    ),
                  ];
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < controls.length; i++) ...[
                          controls[i],
                          if (i != controls.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: controls,
                  );
                },
              ),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<List<DocumentSummary>>(
                  future: _documentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      final message = error is HttpJsonException
                          ? '文档加载失败：${error.message}（HTTP ${error.statusCode}）'
                          : '文档加载失败：$error';
                      return WorkspaceMessageBanner.error(
                        title: '当前还不能选择目标文档',
                        message: message,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final documents = snapshot.data!;
                    if (documents.isEmpty) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkspaceMessageBanner.info(
                            title: '当前还没有可加入的文档',
                            message:
                                '你可以直接在这里新建讲义或试卷，然后继续加入题目。',
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _createDocument,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('新建文档并继续'),
                          ),
                        ],
                      );
                    }

                    final filteredDocuments = _applyFilter(documents);
                    final hasAnySelectableDocument = documents.any(
                      (document) =>
                          !widget.excludedDocumentIds.contains(document.id),
                    );
                    if (!hasAnySelectableDocument) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkspaceMessageBanner.info(
                            title: '当前没有可作为目标的文档',
                            message: '现有文档都属于当前来源文档。你可以新建一份文档继续承接内容。',
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: _createDocument,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('新建文档'),
                          ),
                        ],
                      );
                    }
                    if (filteredDocuments.isEmpty) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkspaceMessageBanner.info(
                            title: '没有匹配的文档',
                            message: '可以调整搜索关键词，或直接新建一个文档继续加入题目。',
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  _queryController.clear();
                                  setState(() {
                                    _query = '';
                                    _kindFilter = 'all';
                                    _exportStatusFilter = 'all';
                                    _sortBy = 'list';
                                  });
                                },
                                icon: const Icon(Icons.filter_alt_off_outlined),
                                label: const Text('清空筛选'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _createDocument,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('新建文档'),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    final questionTotal = filteredDocuments.fold<int>(
                      0,
                      (sum, document) => sum + document.questionCount,
                    );
                    final layoutTotal = filteredDocuments.fold<int>(
                      0,
                      (sum, document) => sum + document.layoutCount,
                    );
                    final handoutCount = filteredDocuments
                        .where((document) => document.kind == 'handout')
                        .length;
                    final paperCount = filteredDocuments
                        .where((document) => document.kind == 'paper')
                        .length;
                    final pendingCount = filteredDocuments
                        .where(
                          (document) =>
                              document.latestExportStatus == 'pending' ||
                              document.latestExportStatus == 'running',
                        )
                        .length;
                    final succeededCount = filteredDocuments
                        .where(
                          (document) =>
                              document.latestExportStatus == 'succeeded',
                        )
                        .length;
                    final failedCount = filteredDocuments
                        .where(
                          (document) => document.latestExportStatus == 'failed',
                        )
                        .length;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SummaryChip(
                                icon: Icons.folder_open_outlined,
                                label: '结果文档',
                                value: '${filteredDocuments.length}',
                              ),
                              _SummaryChip(
                                icon: Icons.quiz_outlined,
                                label: '题目总数',
                                value: '$questionTotal',
                              ),
                              _SummaryChip(
                                icon: Icons.view_quilt_outlined,
                                label: '排版项总数',
                                value: '$layoutTotal',
                              ),
                              _SummaryChip(
                                icon: Icons.menu_book_outlined,
                                label: '讲义',
                                value: '$handoutCount',
                              ),
                              _SummaryChip(
                                icon: Icons.description_outlined,
                                label: '试卷',
                                value: '$paperCount',
                              ),
                              _SummaryChip(
                                icon: Icons.timelapse_outlined,
                                label: '处理中',
                                value: '$pendingCount',
                              ),
                              _SummaryChip(
                                icon: Icons.task_alt_outlined,
                                label: '已完成',
                                value: '$succeededCount',
                              ),
                              _SummaryChip(
                                icon: Icons.error_outline,
                                label: '失败',
                                value: '$failedCount',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredDocuments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final document = filteredDocuments[index];
                              return WorkspacePanel(
                                backgroundColor: TelegramPalette.surfaceSoft,
                                borderRadius: 14,
                                padding: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () =>
                                      Navigator.of(context).pop(document),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: document.kind == 'paper'
                                                ? TelegramPalette.warningSurface
                                                : TelegramPalette.surfaceAccent,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            document.kind == 'paper'
                                                ? Icons.description_outlined
                                                : Icons.menu_book_outlined,
                                            color: TelegramPalette.textStrong,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                document.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              DocumentSummaryPreview(
                                                document: document,
                                                compact: true,
                                                backgroundColor: TelegramPalette
                                                    .surfaceAccent,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_activeFilterEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activeFilterEntries
                        .map(
                          (entry) => _SummaryChip(
                            icon: Icons.tune_outlined,
                            label: entry.$1,
                            value: entry.$2,
                            highlight: true,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton.icon(
                      onPressed: _createDocument,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('新建文档'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return WorkspaceInfoPill(
      icon: icon,
      label: label,
      value: value,
      highlight: highlight,
    );
  }
}
