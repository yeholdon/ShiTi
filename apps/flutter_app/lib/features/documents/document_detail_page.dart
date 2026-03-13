import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/document_detail_args.dart';
import '../../core/models/document_item_summary.dart';
import '../../core/models/document_summary.dart';
import '../../core/models/layout_element_summary.dart';
import '../../core/network/http_json_client.dart';
import '../../core/services/app_services.dart';
import '../../router/app_router.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({
    required this.documentId,
    super.key,
  });

  final String documentId;

  static DocumentDetailPage fromArgs(DocumentDetailArgs args) {
    return DocumentDetailPage(documentId: args.documentId);
  }

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  late final Future<DocumentSummary?> _documentFuture =
      AppServices.instance.documentRepository.getDocument(widget.documentId);
  late Future<List<DocumentItemSummary>> _itemsFuture =
      AppServices.instance.documentRepository.listDocumentItems(widget.documentId);

  void _reloadItems() {
    setState(() {
      _itemsFuture =
          AppServices.instance.documentRepository.listDocumentItems(widget.documentId);
    });
  }

  Future<void> _moveItem(DocumentItemSummary item, int offset) async {
    try {
      await AppServices.instance.documentRepository.moveDocumentItem(
        documentId: widget.documentId,
        itemId: item.id,
        offset: offset,
      );
      _reloadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('调整顺序失败', error);
    }
  }

  Future<void> _removeItem(DocumentItemSummary item) async {
    try {
      await AppServices.instance.documentRepository.removeDocumentItem(
        documentId: widget.documentId,
        itemId: item.id,
      );
      _reloadItems();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除文档项：${item.title}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('移除文档项失败', error);
    }
  }

  Future<void> _exportDocument() async {
    try {
      await AppServices.instance.documentRepository.createExportJob(
        documentId: widget.documentId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建导出任务')),
      );
      Navigator.of(context).pushNamed(AppRouter.exports);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('创建导出任务失败', error);
    }
  }

  Future<void> _addLayoutElement() async {
    try {
      final layoutElements =
          await AppServices.instance.documentRepository.listLayoutElements();
      if (!mounted || layoutElements.isEmpty) {
        return;
      }

      final selected = await showModalBottomSheet<LayoutElementSummary>(
        context: context,
        showDragHandle: true,
        builder: (context) => _LayoutElementPicker(
          layoutElements: layoutElements,
        ),
      );

      if (selected == null) {
        return;
      }

      await AppServices.instance.documentRepository.addLayoutElementToDocument(
        documentId: widget.documentId,
        layoutElement: selected,
      );
      if (!mounted) {
        return;
      }
      _reloadItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已插入排版元素：${selected.name}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showActionError('插入排版元素失败', error);
    }
  }

  void _showActionError(String prefix, Object error) {
    final message = error is HttpJsonException
        ? '$prefix：${error.message}（HTTP ${error.statusCode}）'
        : '$prefix：$error';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文档详情')),
      body: FutureBuilder<DocumentSummary?>(
        future: _documentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is HttpJsonException
                ? '文档加载失败：${error.message}（HTTP ${error.statusCode}）'
                : '文档加载失败：$error';
            return _DocumentErrorCard(message: message);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final document = snapshot.data;
          if (document == null) {
            return const Center(child: Text('未找到对应文档'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _DocumentContextCard(
                modeLabel: AppConfig.dataModeLabel,
                sessionLabel: AppServices.instance.session?.username ?? '未登录',
                tenantLabel: AppServices.instance.activeTenant?.code ?? '未选择租户',
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
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
                          Chip(label: Text(document.kind == 'paper' ? '试卷' : '讲义')),
                          Chip(label: Text('题目 ${document.questionCount}')),
                          Chip(label: Text('排版元素 ${document.layoutCount}')),
                          Chip(label: Text('最近导出 ${document.latestExportStatus}')),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '这里已经开始展示文档项。下一步可以直接接 documents detail / reorder / add-item API，把本地骨架换成真实编排页。',
                        style: TextStyle(height: 1.6, color: Color(0xFF4C6964)),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_note_outlined),
                            label: const Text('继续编排'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _exportDocument,
                            icon: const Icon(Icons.cloud_outlined),
                            label: const Text('导出并查看记录'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<DocumentItemSummary>>(
                future: _itemsFuture,
                builder: (context, itemsSnapshot) {
                  if (itemsSnapshot.hasError) {
                    final error = itemsSnapshot.error;
                    final message = error is HttpJsonException
                        ? '文档项加载失败：${error.message}（HTTP ${error.statusCode}）'
                        : '文档项加载失败：$error';
                    return _DocumentErrorCard(
                      message: message,
                      onRetry: _reloadItems,
                    );
                  }
                  if (!itemsSnapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      _ComposeHintCard(onAddLayoutElement: _addLayoutElement),
                      const SizedBox(height: 12),
                      if (itemsSnapshot.data!.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              '当前文档还没有内容。可以先从题目详情或选题篮加入题目，再在这里插入排版元素。',
                              style: TextStyle(
                                height: 1.5,
                                color: Color(0xFF4C6964),
                              ),
                            ),
                          ),
                        ),
                      ...itemsSnapshot.data!.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DocumentItemCard(
                            item: item,
                            onMoveUp: () => _moveItem(item, -1),
                            onMoveDown: () => _moveItem(item, 1),
                            onRemove: () => _removeItem(item),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComposeHintCard extends StatelessWidget {
  const _ComposeHintCard({required this.onAddLayoutElement});

  final Future<void> Function() onAddLayoutElement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            const SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '文档编排预览',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '这里先展示文档项顺序、题目项和排版元素项。后续接真实接口后，可以在移动端和桌面端共用同一套编排逻辑。',
                    style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAddLayoutElement,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('插入排版元素'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentContextCard extends StatelessWidget {
  const _DocumentContextCard({
    required this.modeLabel,
    required this.sessionLabel,
    required this.tenantLabel,
  });

  final String modeLabel;
  final String sessionLabel;
  final String tenantLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ContextChip(label: '模式', value: modeLabel),
            _ContextChip(label: '会话', value: sessionLabel),
            _ContextChip(label: '租户', value: tenantLabel),
          ],
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: Color(0xFF35524E),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DocumentErrorCard extends StatelessWidget {
  const _DocumentErrorCard({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '文档详情暂时不可用',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(height: 1.5, color: Color(0xFF4C6964)),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新加载'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutElementPicker extends StatelessWidget {
  const _LayoutElementPicker({required this.layoutElements});

  final List<LayoutElementSummary> layoutElements;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            '选择排版元素',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '这里先接本地排版元素列表。后续切到真实接口后，可以直接插入讲义抬头、提问框和总结区。',
            style: TextStyle(height: 1.5, color: Color(0xFF4C6964)),
          ),
          const SizedBox(height: 16),
          ...layoutElements.map(
            (layoutElement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    layoutElement.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      layoutElement.description,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(layoutElement),
                    child: const Text('插入'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentItemCard extends StatelessWidget {
  const _DocumentItemCard({
    required this.item,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final DocumentItemSummary item;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isQuestion = item.kind == 'question';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isQuestion
                    ? const Color(0xFFE7F2EE)
                    : const Color(0xFFF3E9D7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isQuestion ? Icons.quiz_outlined : Icons.view_agenda_outlined,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.detail,
                    style: const TextStyle(color: Color(0xFF52726D)),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  onPressed: onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
