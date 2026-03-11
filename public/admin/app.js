const state = {
  token: localStorage.getItem('admin_token') || '',
  username: localStorage.getItem('admin_username') || '',
  tenantCode: localStorage.getItem('admin_tenant_code') || '',
  tenantName: localStorage.getItem('admin_tenant_name') || '',
  selectedDocumentId: localStorage.getItem('admin_selected_document_id') || '',
  selectedQuestionId: localStorage.getItem('admin_selected_question_id') || '',
  selectedLayoutId: localStorage.getItem('admin_selected_layout_id') || '',
  exportJobId: ''
};
const taxonomyOptions = {
  stages: [],
  grades: [],
  textbooks: [],
  chapters: [],
  tags: []
};

const els = {
  username: document.querySelector('#username'),
  tenantCode: document.querySelector('#tenantCode'),
  tenantName: document.querySelector('#tenantName'),
  authState: document.querySelector('#authState'),
  tenantState: document.querySelector('#tenantState'),
  contextUserChip: document.querySelector('#contextUserChip'),
  contextTenantChip: document.querySelector('#contextTenantChip'),
  contextQuestionChip: document.querySelector('#contextQuestionChip'),
  contextDocumentChip: document.querySelector('#contextDocumentChip'),
  contextLayoutChip: document.querySelector('#contextLayoutChip'),
  apiStatus: document.querySelector('#apiStatus'),
  readyStatus: document.querySelector('#readyStatus'),
  questionsCount: document.querySelector('#questionsCount'),
  documentsCount: document.querySelector('#documentsCount'),
  assetsCount: document.querySelector('#assetsCount'),
  layoutsCount: document.querySelector('#layoutsCount'),
  questionsList: document.querySelector('#questionsList'),
  documentsList: document.querySelector('#documentsList'),
  assetsList: document.querySelector('#assetsList'),
  layoutsList: document.querySelector('#layoutsList'),
  documentDetailName: document.querySelector('#documentDetailName'),
  documentDetailMeta: document.querySelector('#documentDetailMeta'),
  documentStatQuestions: document.querySelector('#documentStatQuestions'),
  documentStatDifficulty: document.querySelector('#documentStatDifficulty'),
  documentItemsCount: document.querySelector('#documentItemsCount'),
  exportJobStatus: document.querySelector('#exportJobStatus'),
  documentItemsList: document.querySelector('#documentItemsList'),
  activityLog: document.querySelector('#activityLog'),
  questionSubjectId: document.querySelector('#questionSubjectId'),
  questionFilterQ: document.querySelector('#questionFilterQ'),
  questionFilterType: document.querySelector('#questionFilterType'),
  questionFilterDifficulty: document.querySelector('#questionFilterDifficulty'),
  questionFilterVisibility: document.querySelector('#questionFilterVisibility'),
  questionFilterTagId: document.querySelector('#questionFilterTagId'),
  questionFilterStageId: document.querySelector('#questionFilterStageId'),
  questionFilterGradeId: document.querySelector('#questionFilterGradeId'),
  questionFilterTextbookId: document.querySelector('#questionFilterTextbookId'),
  questionFilterChapterId: document.querySelector('#questionFilterChapterId'),
  auditFilterAction: document.querySelector('#auditFilterAction'),
  auditFilterTargetType: document.querySelector('#auditFilterTargetType'),
  auditFilterUserId: document.querySelector('#auditFilterUserId'),
  auditFilterSince: document.querySelector('#auditFilterSince'),
  auditFilterUntil: document.querySelector('#auditFilterUntil'),
  auditTotalCount: document.querySelector('#auditTotalCount'),
  auditAnomalyHint: document.querySelector('#auditAnomalyHint'),
  auditActionStatsList: document.querySelector('#auditActionStatsList'),
  auditUserStatsList: document.querySelector('#auditUserStatsList'),
  auditTargetTypeStatsList: document.querySelector('#auditTargetTypeStatsList'),
  auditLogsList: document.querySelector('#auditLogsList'),
  questionDetailName: document.querySelector('#questionDetailName'),
  questionDetailMeta: document.querySelector('#questionDetailMeta'),
  questionType: document.querySelector('#questionType'),
  questionDifficulty: document.querySelector('#questionDifficulty'),
  questionVisibility: document.querySelector('#questionVisibility'),
  questionDefaultScore: document.querySelector('#questionDefaultScore'),
  questionDetailSubjectId: document.querySelector('#questionDetailSubjectId'),
  questionStemText: document.querySelector('#questionStemText'),
  questionExplanationOverview: document.querySelector('#questionExplanationOverview'),
  questionExplanationSteps: document.querySelector('#questionExplanationSteps'),
  questionExplanationCommentary: document.querySelector('#questionExplanationCommentary'),
  questionSourceYear: document.querySelector('#questionSourceYear'),
  questionSourceMonth: document.querySelector('#questionSourceMonth'),
  questionSourceText: document.querySelector('#questionSourceText'),
  questionStageIds: document.querySelector('#questionStageIds'),
  questionGradeIds: document.querySelector('#questionGradeIds'),
  questionTextbookIds: document.querySelector('#questionTextbookIds'),
  questionChapterIds: document.querySelector('#questionChapterIds'),
  questionTagIds: document.querySelector('#questionTagIds'),
  questionChoiceOptions: document.querySelector('#questionChoiceOptions'),
  questionChoiceCorrect: document.querySelector('#questionChoiceCorrect'),
  questionBlankAnswers: document.querySelector('#questionBlankAnswers'),
  questionSolutionFinalAnswer: document.querySelector('#questionSolutionFinalAnswer'),
  questionSolutionScoringPoints: document.querySelector('#questionSolutionScoringPoints'),
  questionTagName: document.querySelector('#questionTagName'),
  questionTagsList: document.querySelector('#questionTagsList'),
  stageCode: document.querySelector('#stageCode'),
  stageName: document.querySelector('#stageName'),
  stageOrder: document.querySelector('#stageOrder'),
  stagesList: document.querySelector('#stagesList'),
  gradeStageId: document.querySelector('#gradeStageId'),
  gradeCode: document.querySelector('#gradeCode'),
  gradeName: document.querySelector('#gradeName'),
  gradeOrder: document.querySelector('#gradeOrder'),
  gradesList: document.querySelector('#gradesList'),
  textbookName: document.querySelector('#textbookName'),
  textbooksList: document.querySelector('#textbooksList'),
  chapterTextbookId: document.querySelector('#chapterTextbookId'),
  chapterName: document.querySelector('#chapterName'),
  chaptersList: document.querySelector('#chaptersList'),
  documentName: document.querySelector('#documentName'),
  documentKind: document.querySelector('#documentKind'),
  layoutText: document.querySelector('#layoutText'),
  assetFile: document.querySelector('#assetFile'),
  addSelectedQuestionToDocumentBtn: document.querySelector('#addSelectedQuestionToDocumentBtn'),
  addSelectedLayoutToDocumentBtn: document.querySelector('#addSelectedLayoutToDocumentBtn'),
  renameSelectedDocumentBtn: document.querySelector('#renameSelectedDocumentBtn'),
  deleteSelectedDocumentBtn: document.querySelector('#deleteSelectedDocumentBtn'),
  exportSelectedDocumentBtn: document.querySelector('#exportSelectedDocumentBtn'),
  downloadExportBtn: document.querySelector('#downloadExportBtn'),
  refreshDocumentDetailBtn: document.querySelector('#refreshDocumentDetailBtn'),
  saveQuestionBasicsBtn: document.querySelector('#saveQuestionBasicsBtn'),
  saveQuestionContentBtn: document.querySelector('#saveQuestionContentBtn'),
  saveQuestionExplanationBtn: document.querySelector('#saveQuestionExplanationBtn'),
  saveQuestionSourceBtn: document.querySelector('#saveQuestionSourceBtn'),
  refreshQuestionDetailBtn: document.querySelector('#refreshQuestionDetailBtn'),
  saveQuestionTagsBtn: document.querySelector('#saveQuestionTagsBtn'),
  saveQuestionTaxonomyBtn: document.querySelector('#saveQuestionTaxonomyBtn'),
  saveQuestionAnswerBtn: document.querySelector('#saveQuestionAnswerBtn'),
  refreshTaxonomyBtn: document.querySelector('#refreshTaxonomyBtn'),
  clearQuestionFiltersBtn: document.querySelector('#clearQuestionFiltersBtn'),
  refreshAuditLogsBtn: document.querySelector('#refreshAuditLogsBtn'),
  auditPreset1hBtn: document.querySelector('#auditPreset1hBtn'),
  auditPreset24hBtn: document.querySelector('#auditPreset24hBtn'),
  clearAuditFiltersBtn: document.querySelector('#clearAuditFiltersBtn'),
  createQuestionTagBtn: document.querySelector('#createQuestionTagBtn'),
  refreshQuestionTagsBtn: document.querySelector('#refreshQuestionTagsBtn'),
  createStageBtn: document.querySelector('#createStageBtn'),
  createGradeBtn: document.querySelector('#createGradeBtn'),
  createTextbookBtn: document.querySelector('#createTextbookBtn'),
  createChapterBtn: document.querySelector('#createChapterBtn')
};

function log(message, payload) {
  const line = `[${new Date().toLocaleTimeString()}] ${message}`;
  els.activityLog.textContent = `${line}${payload ? `\n${JSON.stringify(payload, null, 2)}` : ''}\n\n${els.activityLog.textContent}`.trim();
}

function shortId(value) {
  if (!value) return '未选中';
  return value.length > 10 ? `${value.slice(0, 8)}…` : value;
}

function persistState() {
  localStorage.setItem('admin_token', state.token || '');
  localStorage.setItem('admin_username', state.username || '');
  localStorage.setItem('admin_tenant_code', state.tenantCode || '');
  localStorage.setItem('admin_tenant_name', state.tenantName || '');
  localStorage.setItem('admin_selected_document_id', state.selectedDocumentId || '');
  localStorage.setItem('admin_selected_question_id', state.selectedQuestionId || '');
  localStorage.setItem('admin_selected_layout_id', state.selectedLayoutId || '');
}

function syncInputs() {
  els.username.value = state.username;
  els.tenantCode.value = state.tenantCode;
  els.tenantName.value = state.tenantName;
  els.authState.textContent = state.token ? `已登录：${state.username}` : '尚未登录';
  els.tenantState.textContent = state.tenantCode ? `当前租户：${state.tenantCode}` : '尚未选择租户';
  els.contextUserChip.textContent = state.token ? `用户 · ${state.username}` : '未登录';
  els.contextTenantChip.textContent = state.tenantCode ? `租户 · ${state.tenantCode}` : '未选租户';
  els.contextQuestionChip.textContent = `题目 · ${shortId(state.selectedQuestionId)}`;
  els.contextDocumentChip.textContent = `文档 · ${shortId(state.selectedDocumentId)}`;
  els.contextLayoutChip.textContent = `布局 · ${shortId(state.selectedLayoutId)}`;
}

async function api(path, { method = 'GET', body, tenant = false, headers = {} } = {}) {
  const requestHeaders = { ...headers };
  if (body !== undefined) requestHeaders['Content-Type'] = 'application/json';
  if (state.token) requestHeaders.Authorization = `Bearer ${state.token}`;
  if (tenant && state.tenantCode) requestHeaders['X-Tenant-Code'] = state.tenantCode;

  const res = await fetch(path, {
    method,
    headers: requestHeaders,
    body: body !== undefined ? JSON.stringify(body) : undefined
  });

  let data = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }

  if (!res.ok) {
    throw new Error(data?.message || `${method} ${path} failed with ${res.status}`);
  }

  return data;
}

function renderList(container, items, formatter) {
  container.innerHTML = '';
  if (!items.length) {
    container.innerHTML = '<div class="list-item muted empty-state">当前还没有可展示的数据</div>';
    return;
  }

  for (const item of items) {
    const div = document.createElement('div');
    div.className = 'list-item';
    div.innerHTML = formatter(item);
    container.appendChild(div);
  }
}

function setSelectedDocument(id) {
  state.selectedDocumentId = id || '';
  persistState();
  syncInputs();
}

function setSelectedQuestion(id) {
  state.selectedQuestionId = id || '';
  persistState();
  syncInputs();
}

function setSelectedLayout(id) {
  state.selectedLayoutId = id || '';
  persistState();
  syncInputs();
}

function blocksToEditorText(blocks) {
  if (!Array.isArray(blocks)) return '';
  return blocks
    .map((block) => {
      if (!block || typeof block !== 'object') return '';
      if (typeof block.text === 'string') return block.text.trim();
      return '';
    })
    .filter(Boolean)
    .join('\n');
}

function textToParagraphBlocks(text) {
  return String(text || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => ({ type: 'paragraph', text: line }));
}

function selectedValues(select) {
  return Array.from(select.selectedOptions).map((option) => option.value);
}

function fillMultiSelect(select, items, labelFor) {
  select.innerHTML = '';
  for (const item of items) {
    const option = document.createElement('option');
    option.value = item.id;
    option.textContent = labelFor(item);
    select.appendChild(option);
  }
}

function fillSingleSelect(select, items, labelFor, placeholder = '全部') {
  const currentValue = select.value;
  select.innerHTML = '';

  const emptyOption = document.createElement('option');
  emptyOption.value = '';
  emptyOption.textContent = placeholder;
  select.appendChild(emptyOption);

  for (const item of items) {
    const option = document.createElement('option');
    option.value = item.id;
    option.textContent = labelFor(item);
    select.appendChild(option);
  }

  if (Array.from(select.options).some((option) => option.value === currentValue)) {
    select.value = currentValue;
  }
}

function setMultiSelectValues(select, values) {
  const selected = new Set(values || []);
  for (const option of Array.from(select.options)) {
    option.selected = selected.has(option.value);
  }
}

function optionBlocksToEditorText(optionBlocks) {
  if (!Array.isArray(optionBlocks)) return '';
  return optionBlocks
    .map((option) => {
      const key = option?.key || '';
      const block = Array.isArray(option?.blocks) ? option.blocks[0] : null;
      const child = Array.isArray(block?.children) ? block.children[0] : null;
      const text = typeof child?.text === 'string' ? child.text.trim() : '';
      return `${key}. ${text}`.trim();
    })
    .filter(Boolean)
    .join('\n');
}

function parseChoiceOptions(text) {
  return String(text || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      const match = line.match(/^([A-Za-z])[\.\)]\s*(.+)$/);
      const key = (match?.[1] || String.fromCharCode(65 + index)).toUpperCase();
      const content = (match?.[2] || line).trim();
      return {
        key,
        blocks: [{ type: 'paragraph', children: [{ text: content }] }]
      };
    });
}

function blankAnswersToEditorText(blanks) {
  if (!Array.isArray(blanks)) return '';
  return blanks
    .map((blank) => `${blank.key}: ${(blank.answers || []).join('|')}`)
    .join('\n');
}

function parseBlankAnswers(text) {
  return String(text || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      const [rawKey, rawAnswers] = line.split(':');
      const key = (rawKey || `blank-${index + 1}`).trim();
      const answers = String(rawAnswers || '')
        .split('|')
        .map((item) => item.trim())
        .filter(Boolean);
      return { key, answers };
    });
}

function scoringPointsToEditorText(scoringPoints) {
  if (!Array.isArray(scoringPoints)) return '';
  return scoringPoints.map((item) => `${item.key}|${item.score}|${item.note || ''}`).join('\n');
}

function localDateTimeToIso(value) {
  if (!value) return '';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';
  return parsed.toISOString();
}

function isoToLocalDateTimeValue(value) {
  return new Date(value.getTime() - value.getTimezoneOffset() * 60_000).toISOString().slice(0, 16);
}

function applyAuditPreset(hours) {
  const now = new Date();
  const since = new Date(now.getTime() - hours * 60 * 60 * 1000);
  els.auditFilterSince.value = isoToLocalDateTimeValue(since);
  els.auditFilterUntil.value = isoToLocalDateTimeValue(now);
}

function formatAuditSummary(entry) {
  const details = entry?.details && typeof entry.details === 'object' ? entry.details : null;

  switch (entry.action) {
    case 'question.created':
      return '创建题目';
    case 'question.updated':
      return '更新题目基础信息';
    case 'question.deleted':
      return '删除题目';
    case 'question.content_updated':
      return '更新题干内容';
    case 'question.explanation_updated':
      return '更新题目解析';
    case 'question.source_updated':
      return '更新题目来源';
    case 'question.tags_updated':
      return `更新题目标签${Array.isArray(details?.tagIds) ? ` · ${details.tagIds.length} 个标签` : ''}`;
    case 'question.taxonomy_updated':
      return '更新题目 taxonomy';
    case 'question.choice_answer_updated':
      return '更新选择题答案';
    case 'question.blank_answer_updated':
      return '更新填空题答案';
    case 'question.solution_answer_updated':
      return '更新解答题答案';
    case 'document.created':
      return `创建文档${details?.kind ? ` · ${details.kind}` : ''}`;
    case 'document.updated':
      return '更新文档';
    case 'document.deleted':
      return '删除文档';
    case 'document_item.added':
      return `加入文档项${details?.itemType ? ` · ${details.itemType}` : ''}`;
    case 'document_items.reordered':
      return '调整文档项顺序';
    case 'document_item.removed':
      return '移除文档项';
    case 'asset.upload_created':
      return `创建资源上传${details?.filename ? ` · ${details.filename}` : ''}`;
    case 'asset.deleted':
      return '删除资源';
    case 'question_tag.created':
      return `创建题目标签${details?.name ? ` · ${details.name}` : ''}`;
    case 'question_tag.deleted':
      return '删除题目标签';
    case 'tenant_member.joined':
      return `加入租户${details?.role ? ` · ${details.role}` : ''}`;
    case 'export_job.created':
      return `创建导出任务${details?.kind ? ` · ${details.kind}` : ''}`;
    default:
      return details ? JSON.stringify(details) : '无补充信息';
  }
}

function buildAuditQueryParams() {
  const params = new URLSearchParams({ limit: '30' });
  if (els.auditFilterAction.value.trim()) params.set('action', els.auditFilterAction.value.trim());
  if (els.auditFilterTargetType.value.trim()) params.set('targetType', els.auditFilterTargetType.value.trim());
  if (els.auditFilterUserId.value.trim()) params.set('userId', els.auditFilterUserId.value.trim());

  const sinceIso = localDateTimeToIso(els.auditFilterSince.value);
  const untilIso = localDateTimeToIso(els.auditFilterUntil.value);
  if (sinceIso) params.set('since', sinceIso);
  if (untilIso) params.set('until', untilIso);

  return params;
}

function deriveAuditAnomalyHint(stats) {
  const total = Number(stats?.total || 0);
  if (!total) return '无数据';

  const topAction = Array.isArray(stats?.byAction) ? stats.byAction[0] : null;
  if (topAction && topAction.count >= 10) {
    return `动作 ${topAction.action} 较高频`;
  }

  const topUser = Array.isArray(stats?.byUser) ? stats.byUser[0] : null;
  if (topUser && total >= 5 && topUser.count / total >= 0.7) {
    return `主要由 ${topUser.username || topUser.userId || 'system'} 触发`;
  }

  const topTargetType = Array.isArray(stats?.byTargetType) ? stats.byTargetType[0] : null;
  if (topTargetType && topTargetType.count >= 5) {
    return `${topTargetType.targetType} 相关操作偏多`;
  }

  return '未见明显异常';
}

function parseScoringPoints(text) {
  return String(text || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      const [keyPart, scorePart, ...noteParts] = line.split('|');
      return {
        key: (keyPart || `step-${index + 1}`).trim(),
        score: (scorePart || '0').trim(),
        note: noteParts.join('|').trim()
      };
    });
}

function renderDocumentDetail(document, items) {
  if (!document) {
    els.documentDetailName.textContent = '未选中文档';
    els.documentDetailMeta.textContent = '先在“创建文档”卡片里选择一个文档，再查看详情与导出状态。';
    els.documentStatQuestions.textContent = '0';
    els.documentStatDifficulty.textContent = '-';
    els.documentItemsCount.textContent = '0';
    renderList(els.documentItemsList, [], () => '');
    return;
  }

  els.documentDetailName.textContent = document.name;
  els.documentDetailMeta.textContent = `类型：${document.kind} · 文档 ID：${document.id}`;
  els.documentStatQuestions.textContent = String(document.stats?.totalQuestions ?? 0);
  els.documentStatDifficulty.textContent =
    document.stats?.avgDifficulty == null ? '-' : String(document.stats.avgDifficulty);
  els.documentItemsCount.textContent = String(items.length);

  renderList(
    els.documentItemsList,
    items,
    (item) => `
      <div>
        <strong>${item.itemType === 'question' ? '题目项' : '布局元素'}</strong>
        <span>顺序：${item.orderIndex}</span>
        <span>${item.itemType === 'question' ? `题目 ID：${item.questionId}` : `布局 ID：${item.layoutElementId}`}</span>
        <span>itemId：${item.id}</span>
      </div>
      <div class="list-actions">
        <button data-action="move-document-item-up" data-id="${item.id}">上移</button>
        <button data-action="move-document-item-down" data-id="${item.id}">下移</button>
        <button data-action="remove-document-item" data-id="${item.id}">移除</button>
      </div>
    `
  );
}

function renderQuestionDetail(data) {
  if (!data?.question) {
    els.questionDetailName.textContent = '未选中题目';
    els.questionDetailMeta.textContent = '先在题目列表中选择一题，再编辑基础属性、题干、解析和来源。';
    els.questionType.value = 'single_choice';
    els.questionDifficulty.value = '3';
    els.questionVisibility.value = 'private';
    els.questionDefaultScore.value = '';
    els.questionDetailSubjectId.value = '';
    els.questionStemText.value = '';
    els.questionExplanationOverview.value = '';
    els.questionExplanationSteps.value = '';
    els.questionExplanationCommentary.value = '';
    els.questionSourceYear.value = '';
    els.questionSourceMonth.value = '';
    els.questionSourceText.value = '';
    setMultiSelectValues(els.questionStageIds, []);
    setMultiSelectValues(els.questionGradeIds, []);
    setMultiSelectValues(els.questionTextbookIds, []);
    setMultiSelectValues(els.questionChapterIds, []);
    setMultiSelectValues(els.questionTagIds, []);
    els.questionChoiceOptions.value = '';
    els.questionChoiceCorrect.value = '';
    els.questionBlankAnswers.value = '';
    els.questionSolutionFinalAnswer.value = '';
    els.questionSolutionScoringPoints.value = '';
    return;
  }

  els.questionDetailName.textContent = `题目 ${data.question.id}`;
  els.questionDetailMeta.textContent = `题型：${data.question.type} · owner：${data.question.ownerUserId} · tags：${(data.tags || []).length}`;
  els.questionType.value = data.question.type || 'single_choice';
  els.questionDifficulty.value = String(data.question.difficulty ?? 3);
  els.questionVisibility.value = data.question.visibility || 'private';
  els.questionDefaultScore.value = data.question.defaultScore || '';
  els.questionDetailSubjectId.value = data.question.subjectId || '';
  els.questionStemText.value = blocksToEditorText(data.content?.stemBlocks);
  els.questionExplanationOverview.value = data.explanation?.overviewLatex || '';
  els.questionExplanationSteps.value = blocksToEditorText(data.explanation?.stepsBlocks);
  els.questionExplanationCommentary.value = data.explanation?.commentaryLatex || '';
  els.questionSourceYear.value = data.source?.year == null ? '' : String(data.source.year);
  els.questionSourceMonth.value = data.source?.month == null ? '' : String(data.source.month);
  els.questionSourceText.value = data.source?.sourceText || '';
  setMultiSelectValues(els.questionStageIds, (data.stages || []).map((item) => item.id));
  setMultiSelectValues(els.questionGradeIds, (data.grades || []).map((item) => item.id));
  setMultiSelectValues(els.questionTextbookIds, (data.textbooks || []).map((item) => item.id));
  setMultiSelectValues(els.questionChapterIds, (data.chapters || []).map((item) => item.id));
  setMultiSelectValues(els.questionTagIds, (data.tags || []).map((item) => item.id));
  els.questionChoiceOptions.value = optionBlocksToEditorText(data.choiceAnswer?.optionsBlocks);
  els.questionChoiceCorrect.value = Array.isArray(data.choiceAnswer?.correct) ? data.choiceAnswer.correct.join(',') : '';
  els.questionBlankAnswers.value = blankAnswersToEditorText(data.blankAnswer?.blanks);
  els.questionSolutionFinalAnswer.value = data.solutionAnswer?.finalAnswerLatex || '';
  els.questionSolutionScoringPoints.value = scoringPointsToEditorText(data.solutionAnswer?.scoringPoints);
}

function summaryNames(items) {
  return Array.isArray(items) ? items.map((item) => item.name).filter(Boolean) : [];
}

async function refreshHealth() {
  try {
    const health = await api('/health');
    els.apiStatus.textContent = health.status;
  } catch (error) {
    els.apiStatus.textContent = 'error';
    log('健康检查失败', { error: String(error.message || error) });
  }

  try {
    const ready = await api('/health/ready');
    els.readyStatus.textContent = ready.status;
  } catch (error) {
    els.readyStatus.textContent = 'not_ready';
    log('就绪检查失败', { error: String(error.message || error) });
  }
}

async function refreshQuestions() {
  if (!state.token || !state.tenantCode) return;
  const params = new URLSearchParams({ include: 'tags,summary' });
  if (els.questionFilterQ.value.trim()) params.set('q', els.questionFilterQ.value.trim());
  if (els.questionFilterType.value) params.set('type', els.questionFilterType.value);
  if (els.questionFilterDifficulty.value) params.set('difficulty', els.questionFilterDifficulty.value);
  if (els.questionFilterVisibility.value) params.set('visibility', els.questionFilterVisibility.value);
  if (els.questionFilterTagId.value) params.set('tagId', els.questionFilterTagId.value);
  if (els.questionFilterStageId.value) params.set('stageId', els.questionFilterStageId.value);
  if (els.questionFilterGradeId.value) params.set('gradeId', els.questionFilterGradeId.value);
  if (els.questionFilterTextbookId.value) params.set('textbookId', els.questionFilterTextbookId.value);
  if (els.questionFilterChapterId.value) params.set('chapterId', els.questionFilterChapterId.value);

  const data = await api(`/questions?${params.toString()}`, { tenant: true });
  els.questionsCount.textContent = String(data.questions.length);
  renderList(
    els.questionsList,
    data.questions,
    (question) => `
      <div class="${state.selectedQuestionId === question.id ? 'is-active' : ''}">
        <strong>${question.type}</strong>
        <span>ID: ${question.id}</span>
        <span>difficulty=${question.difficulty}, visibility=${question.visibility}</span>
        <span>${question.summary?.stemPreview || '暂无题干摘要'}</span>
        <span>tags: ${(question.tags || []).map((tag) => tag.name).join(', ') || '-'}</span>
        <span>taxonomy: ${[
          ...summaryNames(question.summary?.stages),
          ...summaryNames(question.summary?.grades),
          ...summaryNames(question.summary?.textbooks),
          ...summaryNames(question.summary?.chapters)
        ].join(' / ') || '-'}</span>
        <div class="list-actions">
          <button data-action="select-question" data-id="${question.id}">查看详情</button>
        </div>
      </div>
    `
  );

  if (state.selectedQuestionId && !data.questions.some((question) => question.id === state.selectedQuestionId)) {
    setSelectedQuestion('');
    renderQuestionDetail(null);
  }
}

async function refreshDocuments() {
  if (!state.token || !state.tenantCode) return;
  const data = await api('/documents', { tenant: true });
  els.documentsCount.textContent = String(data.documents.length);
  renderList(
    els.documentsList,
    data.documents,
    (document) => `
      <div class="${state.selectedDocumentId === document.id ? 'is-active' : ''}">
        <strong>${document.name}</strong>
        <span>${document.kind}</span>
        <span>items=${document.summary?.totalItems ?? 0}, questions=${document.summary?.questionItems ?? 0}, layout=${document.summary?.layoutItems ?? 0}</span>
        <span>avgDifficulty=${document.stats?.avgDifficulty ?? '-'}</span>
        <span>latestExport=${document.summary?.latestExportJob?.status || 'none'}</span>
        <div class="list-actions">
          <button data-action="select-document" data-id="${document.id}">查看详情</button>
          <button data-action="export-document" data-id="${document.id}">导出 PDF</button>
        </div>
      </div>
    `
  );

  if (state.selectedDocumentId && !data.documents.some((document) => document.id === state.selectedDocumentId)) {
    setSelectedDocument('');
    renderDocumentDetail(null, []);
  }
}

async function refreshAssets() {
  if (!state.token || !state.tenantCode) return;
  const data = await api('/assets', { tenant: true });
  els.assetsCount.textContent = String(data.assets.length);
  renderList(
    els.assetsList,
    data.assets,
    (asset) => `<strong>${asset.kind}</strong><span>${asset.mime}</span><span>${asset.storageKey}</span>`
  );
}

async function refreshLayouts() {
  if (!state.token || !state.tenantCode) return;
  const data = await api('/layout-elements', { tenant: true });
  els.layoutsCount.textContent = String(data.layoutElements.length);
  renderList(
    els.layoutsList,
    data.layoutElements,
    (layout) => `
      <div class="${state.selectedLayoutId === layout.id ? 'is-active' : ''}">
        <strong>${layout.id}</strong>
        <span>${JSON.stringify(layout.blocks)}</span>
        <div class="list-actions">
          <button data-action="select-layout" data-id="${layout.id}">选中布局元素</button>
        </div>
      </div>
    `
  );

  if (state.selectedLayoutId && !data.layoutElements.some((layout) => layout.id === state.selectedLayoutId)) {
    setSelectedLayout('');
  }
}

async function refreshAuditLogs() {
  if (!state.token || !state.tenantCode) return;
  const params = buildAuditQueryParams();
  const data = await api(`/audit-logs?${params.toString()}`, { tenant: true });
  renderList(
    els.auditLogsList,
    data.logs || [],
    (entry) => `
      <div>
        <strong>${entry.action}</strong>
        <span>${entry.targetType}${entry.targetId ? ` · ${entry.targetId}` : ''}</span>
        <span>${entry.username ? `user=${entry.username}` : entry.userId ? `user=${entry.userId}` : 'user=system'}</span>
        <span>${entry.at}</span>
        <span>${formatAuditSummary(entry)}</span>
        <span>${entry.details ? JSON.stringify(entry.details) : 'no details'}</span>
      </div>
    `
  );
}

async function refreshAuditStats() {
  if (!state.token || !state.tenantCode) return;
  const params = buildAuditQueryParams();
  params.delete('limit');

  const data = await api(`/audit-logs/stats?${params.toString()}`, { tenant: true });
  els.auditTotalCount.textContent = String(data.stats?.total ?? 0);
  els.auditAnomalyHint.textContent = deriveAuditAnomalyHint(data.stats);
  renderList(
    els.auditActionStatsList,
    data.stats?.byAction || [],
    (entry) => `<strong>${entry.action}</strong><span>${entry.count}</span>`
  );
  renderList(
    els.auditUserStatsList,
    data.stats?.byUser || [],
    (entry) =>
      `<strong>${entry.username || entry.userId || 'system'}</strong><span>${entry.count}</span>`
  );
  renderList(
    els.auditTargetTypeStatsList,
    data.stats?.byTargetType || [],
    (entry) => `<strong>${entry.targetType}</strong><span>${entry.count}</span>`
  );
}

async function refreshAll() {
  await refreshHealth();
  if (!state.token || !state.tenantCode) return;
  await Promise.all([
    refreshQuestions(),
    refreshDocuments(),
    refreshAssets(),
    refreshLayouts(),
    refreshTaxonomyOptions(),
    refreshAuditLogs(),
    refreshAuditStats()
  ]);
  await refreshDocumentDetail();
  await refreshQuestionDetail();
  log('控制台数据已刷新');
}

async function refreshDocumentDetail() {
  if (!state.token || !state.tenantCode || !state.selectedDocumentId) {
    renderDocumentDetail(null, []);
    return;
  }

  const data = await api(`/documents/${state.selectedDocumentId}`, { tenant: true });
  renderDocumentDetail(data.document, data.items || []);
}

async function refreshQuestionDetail() {
  if (!state.token || !state.tenantCode || !state.selectedQuestionId) {
    renderQuestionDetail(null);
    return;
  }

  const data = await api(`/questions/${state.selectedQuestionId}`, { tenant: true });
  renderQuestionDetail(data);
}

async function refreshTaxonomyOptions() {
  if (!state.token || !state.tenantCode) return;

  const [stagesRes, gradesRes, textbooksRes, chaptersRes, tagsRes] = await Promise.all([
    api('/stages', { tenant: true }),
    api('/grades', { tenant: true }),
    api('/textbooks', { tenant: true }),
    api('/chapters', { tenant: true }),
    api('/question-tags', { tenant: true })
  ]);

  taxonomyOptions.stages = stagesRes.stages || [];
  taxonomyOptions.grades = gradesRes.grades || [];
  taxonomyOptions.textbooks = textbooksRes.textbooks || [];
  taxonomyOptions.chapters = chaptersRes.chapters || [];
  taxonomyOptions.tags = tagsRes.tags || [];

  fillMultiSelect(els.questionStageIds, taxonomyOptions.stages, (item) => `${item.name} (${item.code})`);
  fillMultiSelect(els.questionGradeIds, taxonomyOptions.grades, (item) => `${item.name} (${item.code})`);
  fillMultiSelect(els.questionTextbookIds, taxonomyOptions.textbooks, (item) => item.name);
  fillMultiSelect(els.questionChapterIds, taxonomyOptions.chapters, (item) => item.name);
  fillMultiSelect(els.questionTagIds, taxonomyOptions.tags, (item) => item.name);
  fillSingleSelect(els.questionFilterTagId, taxonomyOptions.tags, (item) => item.name);
  fillSingleSelect(els.questionFilterStageId, taxonomyOptions.stages, (item) => `${item.name} (${item.code})`);
  fillSingleSelect(els.questionFilterGradeId, taxonomyOptions.grades, (item) => `${item.name} (${item.code})`);
  fillSingleSelect(els.questionFilterTextbookId, taxonomyOptions.textbooks, (item) => item.name);
  fillSingleSelect(els.questionFilterChapterId, taxonomyOptions.chapters, (item) => item.name);

  fillMultiSelect(els.gradeStageId, taxonomyOptions.stages, (item) => `${item.name} (${item.code})`);
  fillMultiSelect(els.chapterTextbookId, taxonomyOptions.textbooks, (item) => item.name);

  renderList(els.stagesList, taxonomyOptions.stages, (item) => `<strong>${item.name}</strong><span>${item.code}</span>`);
  renderList(els.gradesList, taxonomyOptions.grades, (item) => `<strong>${item.name}</strong><span>${item.code}</span>`);
  renderList(els.textbooksList, taxonomyOptions.textbooks, (item) => `<strong>${item.name}</strong>`);
  renderList(els.chaptersList, taxonomyOptions.chapters, (item) => `<strong>${item.name}</strong><span>${item.textbookId}</span>`);
  renderList(
    els.questionTagsList,
    taxonomyOptions.tags,
    (item) => `
      <div>
        <strong>${item.name}</strong>
        <span>${item.id}</span>
      </div>
      <div class="list-actions">
        <button data-action="delete-question-tag" data-id="${item.id}">删除</button>
      </div>
    `
  );
}

async function createExportJob(documentId) {
  const data = await api('/export-jobs', {
    method: 'POST',
    tenant: true,
    body: { documentId, kind: 'pdf' }
  });
  state.exportJobId = data.job.id;
  els.exportJobStatus.textContent = data.job.status;
  log('已发起导出任务', data.job);
  await pollExportJob();
}

async function addSelectedQuestionToDocument() {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }

  const data = await api(`/documents/${state.selectedDocumentId}/items`, {
    method: 'POST',
    tenant: true,
    body: {
      itemType: 'question',
      questionId: state.selectedQuestionId
    }
  });
  log('已将题目加入文档', data.item);
  await refreshDocumentDetail();
}

async function addSelectedLayoutToDocument() {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }
  if (!state.selectedLayoutId) {
    log('请先选择一个布局元素');
    return;
  }

  const data = await api(`/documents/${state.selectedDocumentId}/items`, {
    method: 'POST',
    tenant: true,
    body: {
      itemType: 'layout_element',
      layoutElementId: state.selectedLayoutId
    }
  });
  log('已将布局元素加入文档', data.item);
  await refreshDocumentDetail();
}

async function renameSelectedDocument() {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }

  const currentName = els.documentDetailName.textContent === '未选中文档' ? '' : els.documentDetailName.textContent;
  const nextName = window.prompt('输入新的文档名称', currentName);
  if (nextName == null) return;

  const trimmed = nextName.trim();
  if (!trimmed) {
    log('文档名称不能为空');
    return;
  }

  const data = await api(`/documents/${state.selectedDocumentId}`, {
    method: 'PATCH',
    tenant: true,
    body: { name: trimmed }
  });
  log('已重命名文档', data.document);
  await refreshDocuments();
  await refreshDocumentDetail();
}

async function deleteSelectedDocument() {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }

  const ok = window.confirm(`确认删除文档“${els.documentDetailName.textContent}”？`);
  if (!ok) return;

  await api(`/documents/${state.selectedDocumentId}`, {
    method: 'DELETE',
    tenant: true
  });
  log('已删除文档', { id: state.selectedDocumentId });
  setSelectedDocument('');
  state.exportJobId = '';
  els.exportJobStatus.textContent = 'idle';
  await refreshDocuments();
  await refreshDocumentDetail();
}

async function reorderDocumentItem(itemId, direction) {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }

  const data = await api(`/documents/${state.selectedDocumentId}`, { tenant: true });
  const items = [...(data.items || [])].sort((a, b) => a.orderIndex - b.orderIndex);
  const index = items.findIndex((item) => item.id === itemId);
  if (index === -1) {
    log('未找到文档项', { itemId });
    return;
  }

  const targetIndex = direction === 'up' ? index - 1 : index + 1;
  if (targetIndex < 0 || targetIndex >= items.length) return;

  const [item] = items.splice(index, 1);
  items.splice(targetIndex, 0, item);

  await api(`/documents/${state.selectedDocumentId}/items/reorder`, {
    method: 'PATCH',
    tenant: true,
    body: {
      items: items.map((current, orderIndex) => ({ id: current.id, orderIndex }))
    }
  });
  log(direction === 'up' ? '已上移文档项' : '已下移文档项', { itemId });
  await refreshDocumentDetail();
  await refreshDocuments();
}

async function removeDocumentItem(itemId) {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }

  await api(`/documents/${state.selectedDocumentId}/items/${itemId}`, {
    method: 'DELETE',
    tenant: true
  });
  log('已移除文档项', { itemId });
  await refreshDocumentDetail();
  await refreshDocuments();
}

async function pollExportJob() {
  if (!state.exportJobId) return;

  for (let attempt = 0; attempt < 12; attempt += 1) {
    const data = await api(`/export-jobs/${state.exportJobId}`, { tenant: true });
    els.exportJobStatus.textContent = data.job.status;
    if (data.job.status === 'succeeded' || data.job.status === 'failed') {
      log('导出任务状态更新', data.job);
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
}

async function downloadExportResult() {
  if (!state.exportJobId) {
    log('当前没有可下载的导出任务');
    return;
  }

  const headers = {};
  if (state.token) headers.Authorization = `Bearer ${state.token}`;
  if (state.tenantCode) headers['X-Tenant-Code'] = state.tenantCode;

  const res = await fetch(`/export-jobs/${state.exportJobId}/result`, { headers });
  if (!res.ok) throw new Error(`Download failed with ${res.status}`);

  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${els.documentDetailName.textContent || 'document'}.pdf`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
  log('已下载导出结果', { exportJobId: state.exportJobId });
}

document.querySelector('#registerBtn').addEventListener('click', async () => {
  state.username = els.username.value.trim();
  const data = await api('/auth/register', { method: 'POST', body: { username: state.username } });
  state.token = data.accessToken;
  persistState();
  syncInputs();
  log('已注册账号', { username: state.username });
});

document.querySelector('#loginBtn').addEventListener('click', async () => {
  state.username = els.username.value.trim();
  const data = await api('/auth/login', { method: 'POST', body: { username: state.username } });
  state.token = data.accessToken;
  persistState();
  syncInputs();
  log('已登录账号', { username: state.username });
});

document.querySelector('#createTenantBtn').addEventListener('click', async () => {
  state.tenantCode = els.tenantCode.value.trim();
  state.tenantName = els.tenantName.value.trim() || state.tenantCode;
  await api('/tenants', { method: 'POST', body: { code: state.tenantCode, name: state.tenantName } });
  persistState();
  syncInputs();
  log('已创建租户', { code: state.tenantCode, name: state.tenantName });
});

document.querySelector('#joinTenantBtn').addEventListener('click', async () => {
  state.tenantCode = els.tenantCode.value.trim();
  await api('/tenant-members', {
    method: 'POST',
    body: { tenantCode: state.tenantCode, role: 'owner' }
  });
  persistState();
  syncInputs();
  log('已加入租户', { code: state.tenantCode });
  await refreshAll();
});

document.querySelector('#createQuestionBtn').addEventListener('click', async () => {
  const subjectId = els.questionSubjectId.value.trim();
  const payload = subjectId ? { subjectId } : {};
  const data = await api('/questions', { method: 'POST', body: payload, tenant: true });
  setSelectedQuestion(data.question.id);
  log('已创建题目', data);
  await refreshQuestions();
  await refreshQuestionDetail();
});

document.querySelector('#createDocumentBtn').addEventListener('click', async () => {
  const name = els.documentName.value.trim();
  const kind = els.documentKind.value;
  const data = await api('/documents', { method: 'POST', body: { name, kind }, tenant: true });
  setSelectedDocument(data.document.id);
  log('已创建文档', data);
  await refreshDocuments();
  await refreshDocumentDetail();
});

document.querySelector('#createLayoutBtn').addEventListener('click', async () => {
  const text = els.layoutText.value.trim();
  const blocks = text ? [{ type: 'paragraph', text }] : [];
  const data = await api('/layout-elements', { method: 'POST', body: { blocks }, tenant: true });
  log('已创建布局元素', data);
  await refreshLayouts();
});

document.querySelector('#uploadAssetBtn').addEventListener('click', async () => {
  const file = els.assetFile.files[0];
  if (!file) {
    log('未选择上传文件');
    return;
  }

  const metadata = await api('/assets/upload', {
    method: 'POST',
    tenant: true,
    body: {
      filename: file.name,
      mime: file.type || 'application/octet-stream',
      size: file.size,
      kind: file.type.startsWith('image/') ? 'image' : 'file'
    }
  });

  const uploadRes = await fetch(metadata.upload.url, {
    method: metadata.upload.method,
    headers: { 'Content-Type': file.type || 'application/octet-stream' },
    body: file
  });

  if (!uploadRes.ok) throw new Error(`Upload failed with ${uploadRes.status}`);

  log('已上传资源', metadata.asset);
  await refreshAssets();
});

document.querySelector('#loadQuestionsBtn').addEventListener('click', refreshQuestions);
document.querySelector('#loadDocumentsBtn').addEventListener('click', refreshDocuments);
document.querySelector('#loadLayoutsBtn').addEventListener('click', refreshLayouts);
document.querySelector('#loadAssetsBtn').addEventListener('click', refreshAssets);
document.querySelector('#refreshBtn').addEventListener('click', refreshAll);
document.querySelector('#exportDocsBtn').addEventListener('click', refreshDocuments);
els.refreshAuditLogsBtn.addEventListener('click', async () => {
  await Promise.all([refreshAuditLogs(), refreshAuditStats()]);
});
els.auditPreset1hBtn.addEventListener('click', async () => {
  applyAuditPreset(1);
  await Promise.all([refreshAuditLogs(), refreshAuditStats()]);
});
els.auditPreset24hBtn.addEventListener('click', async () => {
  applyAuditPreset(24);
  await Promise.all([refreshAuditLogs(), refreshAuditStats()]);
});
els.clearAuditFiltersBtn.addEventListener('click', async () => {
  els.auditFilterAction.value = '';
  els.auditFilterTargetType.value = '';
  els.auditFilterUserId.value = '';
  els.auditFilterSince.value = '';
  els.auditFilterUntil.value = '';
  await Promise.all([refreshAuditLogs(), refreshAuditStats()]);
});
document.querySelector('#clearLogBtn').addEventListener('click', () => {
  els.activityLog.textContent = '';
});
els.clearQuestionFiltersBtn.addEventListener('click', async () => {
  els.questionFilterQ.value = '';
  els.questionFilterType.value = '';
  els.questionFilterDifficulty.value = '';
  els.questionFilterVisibility.value = '';
  els.questionFilterTagId.value = '';
  els.questionFilterStageId.value = '';
  els.questionFilterGradeId.value = '';
  els.questionFilterTextbookId.value = '';
  els.questionFilterChapterId.value = '';
  await refreshQuestions();
});
[
  els.questionFilterType,
  els.questionFilterVisibility,
  els.questionFilterTagId,
  els.questionFilterStageId,
  els.questionFilterGradeId,
  els.questionFilterTextbookId,
  els.questionFilterChapterId
].forEach((select) => {
  select.addEventListener('change', refreshQuestions);
});
els.questionFilterDifficulty.addEventListener('change', refreshQuestions);
els.questionFilterQ.addEventListener('keydown', async (event) => {
  if (event.key !== 'Enter') return;
  event.preventDefault();
  await refreshQuestions();
});
els.questionsList.addEventListener('click', async (event) => {
  const target = event.target.closest('button[data-action="select-question"]');
  if (!target) return;
  const id = target.dataset.id;
  if (!id) return;

  setSelectedQuestion(id);
  await refreshQuestions();
  await refreshQuestionDetail();
});
els.layoutsList.addEventListener('click', async (event) => {
  const target = event.target.closest('button[data-action="select-layout"]');
  if (!target) return;
  const id = target.dataset.id;
  if (!id) return;

  setSelectedLayout(id);
  await refreshLayouts();
});
els.documentsList.addEventListener('click', async (event) => {
  const target = event.target.closest('button[data-action]');
  if (!target) return;

  const action = target.dataset.action;
  const id = target.dataset.id;
  if (!id) return;

  if (action === 'select-document') {
    setSelectedDocument(id);
    await refreshDocuments();
    await refreshDocumentDetail();
    return;
  }

  if (action === 'export-document') {
    setSelectedDocument(id);
    await refreshDocuments();
    await refreshDocumentDetail();
    await createExportJob(id);
  }
});
els.documentItemsList.addEventListener('click', async (event) => {
  const target = event.target.closest('button[data-action]');
  if (!target) return;

  const action = target.dataset.action;
  const id = target.dataset.id;
  if (!id) return;

  if (action === 'move-document-item-up') {
    await reorderDocumentItem(id, 'up');
    return;
  }

  if (action === 'move-document-item-down') {
    await reorderDocumentItem(id, 'down');
    return;
  }

  if (action === 'remove-document-item') {
    await removeDocumentItem(id);
  }
});
els.renameSelectedDocumentBtn.addEventListener('click', renameSelectedDocument);
els.deleteSelectedDocumentBtn.addEventListener('click', deleteSelectedDocument);
els.addSelectedQuestionToDocumentBtn.addEventListener('click', addSelectedQuestionToDocument);
els.addSelectedLayoutToDocumentBtn.addEventListener('click', addSelectedLayoutToDocument);
els.exportSelectedDocumentBtn.addEventListener('click', async () => {
  if (!state.selectedDocumentId) {
    log('请先选择一个文档');
    return;
  }
  await createExportJob(state.selectedDocumentId);
});
els.downloadExportBtn.addEventListener('click', downloadExportResult);
els.refreshDocumentDetailBtn.addEventListener('click', refreshDocumentDetail);
els.saveQuestionBasicsBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }
  const data = await api(`/questions/${state.selectedQuestionId}`, {
    method: 'PATCH',
    tenant: true,
    body: {
      type: els.questionType.value,
      difficulty: Number(els.questionDifficulty.value || '3'),
      visibility: els.questionVisibility.value,
      defaultScore: els.questionDefaultScore.value.trim(),
      subjectId: els.questionDetailSubjectId.value.trim()
    }
  });
  log('已保存题目基础信息', data);
  await refreshQuestions();
  await refreshQuestionDetail();
});
els.saveQuestionContentBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }
  const data = await api(`/questions/${state.selectedQuestionId}/content`, {
    method: 'PUT',
    tenant: true,
    body: { stemBlocks: textToParagraphBlocks(els.questionStemText.value) }
  });
  log('已保存题干', data);
  await refreshQuestionDetail();
});
els.saveQuestionExplanationBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }
  const data = await api(`/questions/${state.selectedQuestionId}/explanation`, {
    method: 'PUT',
    tenant: true,
    body: {
      overviewLatex: els.questionExplanationOverview.value.trim() || null,
      stepsBlocks: textToParagraphBlocks(els.questionExplanationSteps.value),
      commentaryLatex: els.questionExplanationCommentary.value.trim() || null
    }
  });
  log('已保存解析', data);
  await refreshQuestionDetail();
});
els.saveQuestionSourceBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }
  const data = await api(`/questions/${state.selectedQuestionId}/source`, {
    method: 'PUT',
    tenant: true,
    body: {
      year: els.questionSourceYear.value ? Number(els.questionSourceYear.value) : null,
      month: els.questionSourceMonth.value ? Number(els.questionSourceMonth.value) : null,
      sourceText: els.questionSourceText.value.trim() || null
    }
  });
  log('已保存来源', data);
  await refreshQuestionDetail();
});
els.saveQuestionTagsBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }
  const data = await api(`/questions/${state.selectedQuestionId}/tags`, {
    method: 'PUT',
    tenant: true,
    body: {
      tagIds: selectedValues(els.questionTagIds)
    }
  });
  log('已保存题目标签', data);
  await refreshQuestions();
  await refreshQuestionDetail();
});
els.saveQuestionTaxonomyBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }
  const data = await api(`/questions/${state.selectedQuestionId}/taxonomy`, {
    method: 'PUT',
    tenant: true,
    body: {
      stageIds: selectedValues(els.questionStageIds),
      gradeIds: selectedValues(els.questionGradeIds),
      textbookIds: selectedValues(els.questionTextbookIds),
      chapterIds: selectedValues(els.questionChapterIds)
    }
  });
  log('已保存题目 taxonomy', data);
  await refreshQuestionDetail();
});
els.saveQuestionAnswerBtn.addEventListener('click', async () => {
  if (!state.selectedQuestionId) {
    log('请先选择一个题目');
    return;
  }

  if (els.questionType.value === 'single_choice') {
    const data = await api(`/questions/${state.selectedQuestionId}/answer-choice`, {
      method: 'PUT',
      tenant: true,
      body: {
        optionsBlocks: parseChoiceOptions(els.questionChoiceOptions.value),
        correct: els.questionChoiceCorrect.value
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean)
      }
    });
    log('已保存选择题答案', data);
    await refreshQuestionDetail();
    return;
  }

  if (els.questionType.value === 'fill_blank') {
    const data = await api(`/questions/${state.selectedQuestionId}/answer-blank`, {
      method: 'PUT',
      tenant: true,
      body: { blanks: parseBlankAnswers(els.questionBlankAnswers.value) }
    });
    log('已保存填空题答案', data);
    await refreshQuestionDetail();
    return;
  }

  const data = await api(`/questions/${state.selectedQuestionId}/answer-solution`, {
    method: 'PUT',
    tenant: true,
    body: {
      finalAnswerLatex: els.questionSolutionFinalAnswer.value.trim() || null,
      scoringPoints: parseScoringPoints(els.questionSolutionScoringPoints.value)
    }
  });
  log('已保存解答题答案', data);
  await refreshQuestionDetail();
});
els.createQuestionTagBtn.addEventListener('click', async () => {
  const name = els.questionTagName.value.trim();
  if (!name) {
    log('请输入标签名称');
    return;
  }

  const data = await api('/question-tags', {
    method: 'POST',
    tenant: true,
    body: { name }
  });
  els.questionTagName.value = '';
  log('已创建题目标签', data.tag);
  await refreshTaxonomyOptions();
});
els.refreshQuestionTagsBtn.addEventListener('click', refreshTaxonomyOptions);
els.questionTagsList.addEventListener('click', async (event) => {
  const target = event.target.closest('button[data-action="delete-question-tag"]');
  if (!target) return;

  const id = target.dataset.id;
  if (!id) return;

  await api(`/question-tags/${id}`, {
    method: 'DELETE',
    tenant: true
  });
  log('已删除题目标签', { id });
  await refreshTaxonomyOptions();
  await refreshQuestionDetail();
  await refreshQuestions();
});
els.refreshTaxonomyBtn.addEventListener('click', refreshTaxonomyOptions);
els.createStageBtn.addEventListener('click', async () => {
  const data = await api('/stages', {
    method: 'POST',
    tenant: true,
    body: {
      code: els.stageCode.value.trim(),
      name: els.stageName.value.trim(),
      order: Number(els.stageOrder.value || '0')
    }
  });
  log('已创建阶段', data.stage);
  await refreshTaxonomyOptions();
});
els.createGradeBtn.addEventListener('click', async () => {
  const data = await api('/grades', {
    method: 'POST',
    tenant: true,
    body: {
      stageId: els.gradeStageId.value,
      code: els.gradeCode.value.trim(),
      name: els.gradeName.value.trim(),
      order: Number(els.gradeOrder.value || '0')
    }
  });
  log('已创建年级', data.grade);
  await refreshTaxonomyOptions();
});
els.createTextbookBtn.addEventListener('click', async () => {
  const data = await api('/textbooks', {
    method: 'POST',
    tenant: true,
    body: { name: els.textbookName.value.trim() }
  });
  log('已创建教材', data.textbook);
  await refreshTaxonomyOptions();
});
els.createChapterBtn.addEventListener('click', async () => {
  const data = await api('/chapters', {
    method: 'POST',
    tenant: true,
    body: {
      textbookId: els.chapterTextbookId.value,
      name: els.chapterName.value.trim()
    }
  });
  log('已创建章节', data.chapter);
  await refreshTaxonomyOptions();
});
els.refreshQuestionDetailBtn.addEventListener('click', refreshQuestionDetail);

syncInputs();
if (state.token && state.tenantCode) {
  refreshAll();
} else {
  refreshHealth();
}
