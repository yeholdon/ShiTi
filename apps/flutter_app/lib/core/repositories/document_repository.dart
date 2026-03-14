import '../api/shiti_api_client.dart';
import '../models/document_item_summary.dart';
import '../models/document_summary.dart';
import '../models/export_job_summary.dart';
import '../models/layout_element_summary.dart';
import '../models/question_summary.dart';
import '../network/http_json_client.dart';

abstract class DocumentRepository {
  Future<List<DocumentSummary>> listDocuments();

  Future<DocumentSummary> createDocument({
    required String name,
    required String kind,
  });

  Future<DocumentSummary?> getDocument(String documentId);

  Future<List<DocumentItemSummary>> listDocumentItems(String documentId);

  Future<List<LayoutElementSummary>> listLayoutElements();

  Future<DocumentItemSummary> addQuestionToDocument({
    required String documentId,
    required QuestionSummary question,
  });

  Future<List<DocumentItemSummary>> addQuestionsToDocument({
    required String documentId,
    required List<QuestionSummary> questions,
  });

  Future<DocumentItemSummary> addLayoutElementToDocument({
    required String documentId,
    required LayoutElementSummary layoutElement,
  });

  Future<void> moveDocumentItem({
    required String documentId,
    required String itemId,
    required int offset,
  });

  Future<void> removeDocumentItem({
    required String documentId,
    required String itemId,
  });

  Future<ExportJobSummary> createExportJob({
    required String documentId,
  });

  Future<ExportJobSummary> retryExportJob({
    required String jobId,
  });

  Future<List<ExportJobSummary>> listExportJobs();
}

class FakeDocumentRepository implements DocumentRepository {
  const FakeDocumentRepository(this._apiClient);

  final ShiTiApiClient _apiClient;

  @override
  Future<List<DocumentSummary>> listDocuments() {
    return _apiClient.listDocuments();
  }

  @override
  Future<DocumentSummary> createDocument({
    required String name,
    required String kind,
  }) {
    return _apiClient.createDocument(name: name, kind: kind);
  }

  @override
  Future<DocumentSummary?> getDocument(String documentId) {
    return _apiClient.getDocument(documentId);
  }

  @override
  Future<List<DocumentItemSummary>> listDocumentItems(String documentId) {
    return _apiClient.listDocumentItems(documentId);
  }

  @override
  Future<List<LayoutElementSummary>> listLayoutElements() {
    return _apiClient.listLayoutElements();
  }

  @override
  Future<DocumentItemSummary> addQuestionToDocument({
    required String documentId,
    required QuestionSummary question,
  }) {
    return _apiClient.addQuestionToDocument(
      documentId: documentId,
      question: question,
    );
  }

  @override
  Future<List<DocumentItemSummary>> addQuestionsToDocument({
    required String documentId,
    required List<QuestionSummary> questions,
  }) async {
    final items = <DocumentItemSummary>[];
    for (final question in questions) {
      items.add(
        await addQuestionToDocument(
          documentId: documentId,
          question: question,
        ),
      );
    }
    return items;
  }

  @override
  Future<DocumentItemSummary> addLayoutElementToDocument({
    required String documentId,
    required LayoutElementSummary layoutElement,
  }) {
    return _apiClient.addLayoutElementToDocument(
      documentId: documentId,
      layoutElement: layoutElement,
    );
  }

  @override
  Future<void> moveDocumentItem({
    required String documentId,
    required String itemId,
    required int offset,
  }) {
    return _apiClient.moveDocumentItem(
      documentId: documentId,
      itemId: itemId,
      offset: offset,
    );
  }

  @override
  Future<void> removeDocumentItem({
    required String documentId,
    required String itemId,
  }) {
    return _apiClient.removeDocumentItem(
      documentId: documentId,
      itemId: itemId,
    );
  }

  @override
  Future<ExportJobSummary> createExportJob({
    required String documentId,
  }) {
    return _apiClient.createExportJob(documentId: documentId);
  }

  @override
  Future<ExportJobSummary> retryExportJob({
    required String jobId,
  }) {
    return _apiClient.retryExportJob(jobId: jobId);
  }

  @override
  Future<List<ExportJobSummary>> listExportJobs() {
    return _apiClient.listExportJobs();
  }
}

class RemoteDocumentRepository implements DocumentRepository {
  const RemoteDocumentRepository(this._client);

  final HttpJsonClient _client;

  @override
  Future<List<DocumentSummary>> listDocuments() async {
    final items = await _client.getList('/documents', listKey: 'documents');
    return items.whereType<Map<String, dynamic>>().map(_mapDocument).toList();
  }

  @override
  Future<DocumentSummary> createDocument({
    required String name,
    required String kind,
  }) async {
    final object = await _client.postObject(
      '/documents',
      body: <String, dynamic>{
        'name': name,
        'kind': kind,
      },
    );
    final document = object['document'];
    if (document is Map<String, dynamic>) {
      return _mapDocument(document);
    }
    return DocumentSummary(
      id: '',
      name: name,
      kind: kind,
      questionCount: 0,
      layoutCount: 0,
      latestExportStatus: 'not_started',
    );
  }

  @override
  Future<DocumentSummary?> getDocument(String documentId) async {
    final object = await _client.getObject(
      '/documents/$documentId',
      objectKey: 'document',
    );
    if (object.isEmpty) {
      return null;
    }
    return _mapDocument(object);
  }

  @override
  Future<List<DocumentItemSummary>> listDocumentItems(String documentId) async {
    final object = await _client.getObject('/documents/$documentId');
    final items = object['items'];
    if (items is! List) {
      return const <DocumentItemSummary>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => DocumentItemSummary(
            id: (item['id'] ?? '').toString(),
            kind: (item['itemType'] ?? item['kind'] ?? 'question').toString(),
            title: (item['title'] ?? item['refId'] ?? '未命名文档项').toString(),
            detail: (item['detail'] ?? item['summary'] ?? '').toString(),
            previewBlocks: _mapPreviewBlocks(item),
          ),
        )
        .toList();
  }

  @override
  Future<List<LayoutElementSummary>> listLayoutElements() async {
    final items = await _client.getList(
      '/layout-elements',
      listKey: 'layoutElements',
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => LayoutElementSummary(
            id: (item['id'] ?? '').toString(),
            name: (item['name'] ?? '未命名排版元素').toString(),
            description: (item['detail'] ?? item['summary'] ?? item['name'] ?? '')
                .toString(),
            previewBlocks: _mapPreviewBlocks(item),
          ),
        )
        .toList();
  }

  @override
  Future<DocumentItemSummary> addQuestionToDocument({
    required String documentId,
    required QuestionSummary question,
  }) async {
    final object = await _client.postObject(
      '/documents/$documentId/items',
      body: <String, dynamic>{
        'itemType': 'question',
        'refId': question.id,
      },
    );
    final item = object['item'];
    return DocumentItemSummary(
      id: item is Map<String, dynamic> ? (item['id'] ?? '').toString() : '',
      kind: 'question',
      title: question.title,
      detail: '新增题目 · ${question.chapter}',
      previewBlocks: <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': question.stemPreview},
      ],
    );
  }

  @override
  Future<List<DocumentItemSummary>> addQuestionsToDocument({
    required String documentId,
    required List<QuestionSummary> questions,
  }) async {
    if (questions.isEmpty) {
      return const <DocumentItemSummary>[];
    }

    final object = await _client.postObject(
      '/documents/$documentId/items/bulk',
      body: <String, dynamic>{
        'items': [
          for (final question in questions)
            <String, dynamic>{
              'itemType': 'question',
              'refId': question.id,
            },
        ],
      },
    );

    final items = object['items'];
    if (items is! List) {
      return <DocumentItemSummary>[
        for (final question in questions)
          DocumentItemSummary(
            id: '',
            kind: 'question',
            title: question.title,
            detail: '新增题目 · ${question.chapter}',
            previewBlocks: <Map<String, dynamic>>[
              <String, dynamic>{'type': 'text', 'text': question.stemPreview},
            ],
          ),
      ];
    }

    final createdItems = items.whereType<Map<String, dynamic>>().toList();
    return <DocumentItemSummary>[
      for (var index = 0; index < questions.length; index++)
        DocumentItemSummary(
          id: index < createdItems.length
              ? (createdItems[index]['id'] ?? '').toString()
              : '',
          kind: 'question',
          title: questions[index].title,
          detail: '新增题目 · ${questions[index].chapter}',
          previewBlocks: <Map<String, dynamic>>[
            <String, dynamic>{'type': 'text', 'text': questions[index].stemPreview},
          ],
        ),
    ];
  }

  @override
  Future<DocumentItemSummary> addLayoutElementToDocument({
    required String documentId,
    required LayoutElementSummary layoutElement,
  }) async {
    final object = await _client.postObject(
      '/documents/$documentId/items',
      body: <String, dynamic>{
        'itemType': 'layout_element',
        'refId': layoutElement.id,
      },
    );
    final item = object['item'];
    return DocumentItemSummary(
      id: item is Map<String, dynamic> ? (item['id'] ?? '').toString() : '',
      kind: 'layout_element',
      title: layoutElement.name,
      detail: layoutElement.description,
      previewBlocks: layoutElement.previewBlocks,
    );
  }

  @override
  Future<void> moveDocumentItem({
    required String documentId,
    required String itemId,
    required int offset,
  }) async {
    final items = await listDocumentItems(documentId);
    final currentIndex = items.indexWhere((item) => item.id == itemId);
    if (currentIndex < 0) {
      return;
    }
    final nextIndex = currentIndex + offset;
    if (nextIndex < 0 || nextIndex >= items.length) {
      return;
    }

    final reordered = List<DocumentItemSummary>.from(items);
    final item = reordered.removeAt(currentIndex);
    reordered.insert(nextIndex, item);

    await _client.patchObject(
      '/documents/$documentId/items/reorder',
      body: <String, dynamic>{
        'items': [
          for (var index = 0; index < reordered.length; index++)
            <String, dynamic>{
              'id': reordered[index].id,
              'orderIndex': index,
            },
        ],
      },
    );
  }

  @override
  Future<void> removeDocumentItem({
    required String documentId,
    required String itemId,
  }) async {
    await _client.deleteObject('/documents/$documentId/items/$itemId');
  }

  @override
  Future<ExportJobSummary> createExportJob({
    required String documentId,
  }) async {
    final object = await _client.postObject(
      '/export-jobs',
      body: <String, dynamic>{
        'documentId': documentId,
        'format': 'pdf',
      },
    );

    final job = object['job'];
    if (job is Map<String, dynamic>) {
      return ExportJobSummary(
        id: (job['id'] ?? '').toString(),
        documentId: job['documentId']?.toString(),
        documentName: (job['documentName'] ?? job['documentId'] ?? documentId)
            .toString(),
        format: (job['format'] ?? 'pdf').toString(),
        status: (job['status'] ?? 'pending').toString(),
        updatedAtLabel: (job['updatedAt'] ?? job['createdAt'] ?? '刚刚').toString(),
      );
    }

    return ExportJobSummary(
      id: '',
      documentId: documentId,
      documentName: documentId,
      format: 'pdf',
      status: 'pending',
      updatedAtLabel: '刚刚',
    );
  }

  @override
  Future<ExportJobSummary> retryExportJob({
    required String jobId,
  }) async {
    final object = await _client.postObject('/export-jobs/$jobId/retry');
    final job = object['job'];
    if (job is Map<String, dynamic>) {
      return ExportJobSummary(
        id: (job['id'] ?? '').toString(),
        documentId: job['documentId']?.toString(),
        documentName: (job['documentName'] ?? job['documentId'] ?? '未命名文档')
            .toString(),
        format: (job['format'] ?? 'pdf').toString(),
        status: (job['status'] ?? 'pending').toString(),
        updatedAtLabel: (job['updatedAt'] ?? job['createdAt'] ?? '刚刚').toString(),
      );
    }

    return ExportJobSummary(
      id: jobId,
      documentName: '未命名文档',
      format: 'pdf',
      status: 'pending',
      updatedAtLabel: '刚刚',
    );
  }

  @override
  Future<List<ExportJobSummary>> listExportJobs() async {
    final items = await _client.getList('/export-jobs', listKey: 'jobs');
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ExportJobSummary(
            id: (item['id'] ?? '').toString(),
            documentId: item['documentId']?.toString(),
            documentName: (item['documentName'] ?? item['documentId'] ?? '未命名文档')
                .toString(),
            format: (item['format'] ?? 'pdf').toString(),
            status: (item['status'] ?? 'pending').toString(),
            updatedAtLabel: (item['updatedAt'] ?? item['createdAt'] ?? '刚刚')
                .toString(),
          ),
        )
        .toList();
  }

  DocumentSummary _mapDocument(Map<String, dynamic> json) {
    final summary = json['summary'];
    final summaryMap = summary is Map<String, dynamic>
        ? summary
        : const <String, dynamic>{};
    final latestExportJob = summaryMap['latestExportJob'];
    final latestExportMap = latestExportJob is Map<String, dynamic>
        ? latestExportJob
        : const <String, dynamic>{};
    return DocumentSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '未命名文档').toString(),
      kind: (json['kind'] ?? 'handout').toString(),
      questionCount: (summaryMap['questionItems'] as num?)?.toInt() ?? 0,
      layoutCount: (summaryMap['layoutItems'] as num?)?.toInt() ?? 0,
      latestExportStatus: (latestExportMap['status'] ?? 'not_started').toString(),
      latestExportJobId: latestExportMap['id']?.toString(),
      previewBlocks: _mapDocumentPreviewBlocks(json, summaryMap),
    );
  }

  List<Map<String, dynamic>> _mapDocumentPreviewBlocks(
    Map<String, dynamic> json,
    Map<String, dynamic> summaryMap,
  ) {
    final directBlocks = summaryMap['previewBlocks'] ?? json['previewBlocks'];
    if (directBlocks is List) {
      return directBlocks.whereType<Map<String, dynamic>>().toList();
    }

    final name = (json['name'] ?? '').toString().trim();
    final kind = (json['kind'] ?? 'handout').toString();
    final questionItems = (summaryMap['questionItems'] as num?)?.toInt() ?? 0;
    final layoutItems = (summaryMap['layoutItems'] as num?)?.toInt() ?? 0;
    final latestStatus = ((summaryMap['latestExportJob'] as Map<String, dynamic>?)?['status'] ??
            'not_started')
        .toString();
    final text = <String>[
      if (name.isNotEmpty) name,
      kind == 'paper' ? '试卷编排' : '讲义编排',
      '题目 $questionItems',
      '排版 $layoutItems',
      '导出 $latestStatus',
    ].join(' · ');
    return <Map<String, dynamic>>[
      <String, dynamic>{'type': 'text', 'text': text},
    ];
  }

  List<Map<String, dynamic>> _mapPreviewBlocks(Map<String, dynamic> item) {
    final directBlocks = item['blocks'];
    if (directBlocks is List) {
      return directBlocks.whereType<Map<String, dynamic>>().toList();
    }

    final preview = item['summary'] ?? item['detail'] ?? item['title'] ?? item['refId'];
    final text = preview?.toString().trim() ?? '';
    if (text.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'text',
        'text': text,
      },
    ];
  }
}
