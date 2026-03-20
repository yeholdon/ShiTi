import 'package:flutter/material.dart';

import '../../core/models/tenant_member_summary.dart';
import '../../core/models/tenant_member_audit_event.dart';
import '../../core/services/app_services.dart';
import '../../core/theme/telegram_palette.dart';
import '../../router/app_router.dart';
import '../shared/workspace_shell.dart';

class TenantMembersPage extends StatefulWidget {
  const TenantMembersPage({super.key});

  @override
  State<TenantMembersPage> createState() => _TenantMembersPageState();
}

class _TenantMembersPageState extends State<TenantMembersPage> {
  final _searchController = TextEditingController();
  List<TenantMemberSummary> _members = const <TenantMemberSummary>[];
  final Map<String, _TenantMemberRecentAction> _recentActions =
      <String, _TenantMemberRecentAction>{};
  final Map<String, List<_TenantMemberRecentAction>> _actionHistory =
      <String, List<_TenantMemberRecentAction>>{};
  final Map<String, GlobalKey> _memberCardKeys = <String, GlobalKey>{};
  String? _activeQueueKind;
  String? _activeQueueSectionKey;
  String? _activeQueueTitle;
  String? _activeQueuePriorityMemberId;
  String? _activeQueueCompletionMessage;
  String? _focusedMemberId;
  Object? _error;
  bool _loading = true;
  String? _updatingMemberId;
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  String _scopeFilter = 'all';
  String _sortMode = 'list';

  bool get _canManageRoles =>
      (AppServices.instance.activeTenant?.role ?? '') == 'owner';

  bool get _canManageStatuses {
    final role = AppServices.instance.activeTenant?.role ?? '';
    return role == 'owner' || role == 'admin';
  }

  bool get _canRemoveMembers {
    final role = AppServices.instance.activeTenant?.role ?? '';
    return role == 'owner' || role == 'admin';
  }

  bool get _canAddMembers {
    final role = AppServices.instance.activeTenant?.role ?? '';
    return role == 'owner' || role == 'admin';
  }

  String get _activeRole => AppServices.instance.activeTenant?.role ?? '';

  String get _activeUserId => AppServices.instance.session?.userId ?? '';

  String get _tenantCode => AppServices.instance.activeTenant?.code ?? '';

  int get _manageableCount => _members.where(_isManageable).length;

  int get _visibleManageableCount =>
      _visibleMembers.where(_isManageable).length;

  int get _visibleExpiredInviteCount => _visibleMembers
      .where(
          (member) => member.status == 'invited' && member.isInvitationExpired)
      .length;

  int get _visibleResentInviteCount => _visibleMembers
      .where(
        (member) =>
            member.status == 'invited' &&
            _recentActions[member.id]?.title == '邀请已重发',
      )
      .length;

  int get _visibleFreshInviteCount =>
      _visibleCountByStatus('invited') - _visibleExpiredInviteCount;

  bool get _visibleIncludesActiveUser =>
      _visibleMembers.any((member) => member.userId == _activeUserId);

  TenantMemberSummary? get _activeUserMember =>
      _members.cast<TenantMemberSummary?>().firstWhere(
            (member) => member?.userId == _activeUserId,
            orElse: () => null,
          );

  int _countByStatus(String status) =>
      _members.where((member) => member.status == status).length;

  int _countByRole(String role) =>
      _members.where((member) => member.role == role).length;

  int _visibleCountByStatus(String status) =>
      _visibleMembers.where((member) => member.status == status).length;

  int _visibleCountByRole(String role) =>
      _visibleMembers.where((member) => member.role == role).length;

  int get _expiredInviteCount => _members
      .where(
          (member) => member.status == 'invited' && member.isInvitationExpired)
      .length;

  int get _resentInviteCount => _members
      .where(
        (member) =>
            member.status == 'invited' &&
            _recentActions[member.id]?.title == '邀请已重发',
      )
      .length;

  Iterable<TenantMemberSummary> get _expiredInviteMembers => _members.where(
        (member) => member.status == 'invited' && member.isInvitationExpired,
      );

  Iterable<TenantMemberSummary> get _freshInviteMembers => _members.where(
        (member) => member.status == 'invited' && !member.isInvitationExpired,
      );

  Iterable<TenantMemberSummary> get _resentInviteMembersList => _members.where(
        (member) =>
            member.status == 'invited' &&
            _recentActions[member.id]?.title == '邀请已重发',
      );

  List<String> get _invitationRunbookLines {
    final lines = <String>[];
    if (_countByStatus('invited') == 0) {
      lines.add('当前没有待加入成员，邀请队列已清空。');
      return lines;
    }
    if (_expiredInviteCount > 0) {
      lines.add('先处理 $_expiredInviteCount 个已过期邀请，优先重发或撤销。');
    }
    final freshInvites = _countByStatus('invited') - _expiredInviteCount;
    if (freshInvites > 0) {
      lines.add('再跟进 $freshInvites 个仍在有效期内的待加入成员。');
    }
    if (_resentInviteCount > 0) {
      lines.add('本轮已重发 $_resentInviteCount 个邀请，适合回看这批成员是否已经完成加入。');
    }
    return lines;
  }

  List<String> get _activeFilterLabels {
    final labels = <String>[];
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      labels.add('搜索：$query');
    }
    if (_roleFilter != 'all') {
      labels.add('角色：${_roleMeta(_roleFilter).label}');
    }
    if (_statusFilter != 'all') {
      labels.add(
        switch (_statusFilter) {
          'active' => '状态：活跃',
          'invited' => '状态：待加入',
          _ => '状态：已停用',
        },
      );
    }
    if (_scopeFilter != 'all') {
      labels.add(
        switch (_scopeFilter) {
          'manageable' => '范围：仅看可操作',
          'current_user' => '范围：仅看当前账号',
          'expired_invites' => '范围：仅看过期邀请',
          'resent_invites' => '范围：仅看已重发邀请',
          'manageable_expired_invites' => '范围：可操作的过期邀请',
          _ => '范围：全部对象',
        },
      );
    }
    if (_sortMode != 'list') {
      labels.add(
        switch (_sortMode) {
          'username' => '排序：按用户名',
          'role' => '排序：按角色',
          'status' => '排序：按状态',
          _ => '排序：列表顺序',
        },
      );
    }
    return labels;
  }

  String _queuePreview(
    Iterable<TenantMemberSummary> members, {
    required String emptyLabel,
  }) {
    final names = members.map((member) => member.username).take(3).toList();
    if (names.isEmpty) {
      return emptyLabel;
    }
    final suffix =
        members.length > names.length ? ' 等 ${members.length} 位' : '';
    return '当前优先对象：${names.join('、')}$suffix';
  }

  void _applyQuickView({
    required String statusFilter,
    required String scopeFilter,
    String? roleFilter,
  }) {
    setState(() {
      _statusFilter = statusFilter;
      _scopeFilter = scopeFilter;
      _activeQueueKind = null;
      _activeQueueSectionKey = null;
      _activeQueueTitle = null;
      _activeQueuePriorityMemberId = null;
      _activeQueueCompletionMessage = null;
      if (roleFilter != null) {
        _roleFilter = roleFilter;
      }
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _roleFilter = 'all';
      _statusFilter = 'all';
      _scopeFilter = 'all';
      _activeQueueKind = null;
      _activeQueueSectionKey = null;
      _activeQueueTitle = null;
      _activeQueuePriorityMemberId = null;
      _activeQueueCompletionMessage = null;
    });
  }

  void _applyQuickViewAndFocusFirst({
    required String statusFilter,
    required String scopeFilter,
    required Iterable<TenantMemberSummary> members,
    required String queueKind,
    required String queueSectionKey,
    required String queueTitle,
    String? roleFilter,
  }) {
    _applyQuickView(
      statusFilter: statusFilter,
      scopeFilter: scopeFilter,
      roleFilter: roleFilter,
    );
    final target = members.isEmpty ? null : members.first;
    setState(() {
      _activeQueueKind = queueKind;
      _activeQueueSectionKey = queueSectionKey;
      _activeQueueTitle = queueTitle;
      _activeQueuePriorityMemberId = target?.id;
      _activeQueueCompletionMessage =
          target == null ? '$queueTitle 已清空。' : null;
    });
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusMember(target);
      });
    }
  }

  GlobalKey _keyForMember(String memberId) =>
      _memberCardKeys.putIfAbsent(memberId, GlobalKey.new);

  void _focusMember(TenantMemberSummary member) {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final hiddenBySearch = searchQuery.isNotEmpty &&
        !member.username.toLowerCase().contains(searchQuery);
    setState(() {
      if (_roleFilter != 'all' && _roleFilter != member.role) {
        _roleFilter = 'all';
      }
      if (_statusFilter != 'all' && _statusFilter != member.status) {
        _statusFilter = 'all';
      }
      if (_scopeFilter != 'all') {
        _scopeFilter = 'all';
      }
      if (hiddenBySearch) {
        _searchController.clear();
      }
      _focusedMemberId = member.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keyForMember(member.id).currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }
    });
  }

  void _recordRecentAction(String memberId, _TenantMemberRecentAction action) {
    _recentActions[memberId] = action;
    final existing =
        _actionHistory[memberId] ?? const <_TenantMemberRecentAction>[];
    _actionHistory[memberId] = <_TenantMemberRecentAction>[
      action,
      ...existing,
    ].take(4).toList();
  }

  Iterable<TenantMemberSummary> _membersForActiveQueue() {
    return switch (_activeQueueKind) {
      'expired_invites' => _expiredInviteMembers,
      'fresh_invites' => _freshInviteMembers,
      'resent_invites' => _resentInviteMembersList,
      _ => const <TenantMemberSummary>[],
    };
  }

  TenantMemberSummary? _syncActiveQueueAfterTargetMutation(String memberId) {
    if (_activeQueueKind == null) {
      return null;
    }
    final queueMembers = _membersForActiveQueue().toList();
    if (queueMembers.isEmpty) {
      _activeQueuePriorityMemberId = null;
      _activeQueueCompletionMessage = '${_activeQueueTitle ?? '当前处理队列'} 已清空。';
      return null;
    }
    _activeQueueCompletionMessage = null;
    final nextTarget = queueMembers.first;
    _activeQueuePriorityMemberId = nextTarget.id;
    final processedStillInQueue =
        queueMembers.any((member) => member.id == memberId);
    return processedStillInQueue ? null : nextTarget;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final tenantCode = _tenantCode;
    if (tenantCode.isEmpty) {
      setState(() {
        _members = const <TenantMemberSummary>[];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final members =
          await AppServices.instance.sessionRepository.listTenantMembers(
        tenantCode: tenantCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<TenantMemberSummary> get _visibleMembers {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _members.where((member) {
      final roleMatches = _roleFilter == 'all' || member.role == _roleFilter;
      final statusMatches =
          _statusFilter == 'all' || member.status == _statusFilter;
      final scopeMatches = _scopeFilter == 'all' ||
          (_scopeFilter == 'current_user' && member.userId == _activeUserId) ||
          (_scopeFilter == 'manageable' && _isManageable(member)) ||
          (_scopeFilter == 'manageable_expired_invites' &&
              _isManageable(member) &&
              member.status == 'invited' &&
              member.isInvitationExpired) ||
          (_scopeFilter == 'resent_invites' &&
              member.status == 'invited' &&
              _recentActions[member.id]?.title == '邀请已重发') ||
          (_scopeFilter == 'expired_invites' &&
              member.status == 'invited' &&
              member.isInvitationExpired);
      final queryMatches =
          query.isEmpty || member.username.toLowerCase().contains(query);
      return roleMatches && statusMatches && scopeMatches && queryMatches;
    }).toList();
    switch (_sortMode) {
      case 'username':
        filtered.sort((left, right) => left.username.compareTo(right.username));
      case 'role':
        filtered.sort((left, right) {
          final rankDiff = _roleRank(left.role) - _roleRank(right.role);
          if (rankDiff != 0) {
            return rankDiff;
          }
          return left.username.compareTo(right.username);
        });
      case 'status':
        filtered.sort((left, right) {
          final rankDiff =
              _tenantMemberStatusRank(left) - _tenantMemberStatusRank(right);
          if (rankDiff != 0) {
            return rankDiff;
          }
          return left.username.compareTo(right.username);
        });
      default:
        break;
    }
    return filtered;
  }

  bool _canManageRolesForMember(TenantMemberSummary member) {
    if (_activeRole != 'owner') {
      return false;
    }
    return member.userId != _activeUserId;
  }

  bool _canManageStatusForMember(TenantMemberSummary member) {
    if (_activeRole == 'owner') {
      return !(member.userId == _activeUserId && member.status == 'active');
    }
    if (_activeRole == 'admin') {
      return member.role == 'member';
    }
    return false;
  }

  bool _canRemoveMemberForMember(TenantMemberSummary member) {
    if (_activeRole == 'owner') {
      return member.userId != _activeUserId;
    }
    if (_activeRole == 'admin') {
      return member.role == 'member';
    }
    return false;
  }

  bool _isManageable(TenantMemberSummary member) {
    return _canManageRolesForMember(member) ||
        _canManageStatusForMember(member) ||
        _canRemoveMemberForMember(member);
  }

  List<_TenantMemberSection> get _visibleSections {
    final grouped = <String, List<TenantMemberSummary>>{
      'active': <TenantMemberSummary>[],
      'invited_valid': <TenantMemberSummary>[],
      'invited_expired': <TenantMemberSummary>[],
      'disabled': <TenantMemberSummary>[],
    };

    for (final member in _visibleMembers) {
      if (member.status == 'invited') {
        final key =
            member.isInvitationExpired ? 'invited_expired' : 'invited_valid';
        grouped.putIfAbsent(key, () => <TenantMemberSummary>[]).add(member);
      } else {
        grouped
            .putIfAbsent(member.status, () => <TenantMemberSummary>[])
            .add(member);
      }
    }

    for (final members in grouped.values) {
      members.sort((left, right) {
        final roleComparison =
            _roleRank(left.role).compareTo(_roleRank(right.role));
        if (roleComparison != 0) {
          return roleComparison;
        }
        return left.username
            .toLowerCase()
            .compareTo(right.username.toLowerCase());
      });
    }

    return <_TenantMemberSection>[
      _TenantMemberSection(
        sectionKey: 'active',
        status: 'active',
        filterStatus: 'active',
        filterScope: 'all',
        label: '活跃',
        hint: '活跃成员可以继续调整角色，或处理日常成员变更。',
        members: grouped['active'] ?? const <TenantMemberSummary>[],
      ),
      _TenantMemberSection(
        sectionKey: 'invited_valid',
        status: 'invited',
        filterStatus: 'invited',
        filterScope: 'all',
        label: '待加入',
        hint: '优先处理仍在有效期内的邀请，决定激活还是撤销邀请。',
        members: grouped['invited_valid'] ?? const <TenantMemberSummary>[],
      ),
      _TenantMemberSection(
        sectionKey: 'invited_expired',
        status: 'invited',
        filterStatus: 'invited',
        filterScope: 'expired_invites',
        label: '已过期邀请',
        hint: '这里集中处理已过期邀请，优先重发邀请或撤销当前待加入关系。',
        members: grouped['invited_expired'] ?? const <TenantMemberSummary>[],
      ),
      _TenantMemberSection(
        sectionKey: 'disabled',
        status: 'disabled',
        filterStatus: 'disabled',
        filterScope: 'all',
        label: '已停用',
        hint: '这里集中查看暂时停用的账号，决定是否恢复访问。',
        members: grouped['disabled'] ?? const <TenantMemberSummary>[],
      ),
    ].where((section) => section.members.isNotEmpty).toList();
  }

  Future<void> _updateRole(TenantMemberSummary member, String nextRole) async {
    setState(() {
      _updatingMemberId = member.id;
    });
    try {
      final updated =
          await AppServices.instance.sessionRepository.updateTenantMemberRole(
        tenantCode: _tenantCode,
        memberId: member.id,
        role: nextRole,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final index = _members.indexWhere((entry) => entry.id == updated.id);
        if (index >= 0) {
          _members = <TenantMemberSummary>[
            ..._members.take(index),
            updated,
            ..._members.skip(index + 1),
          ];
        }
        _recordRecentAction(
          updated.id,
          _TenantMemberRecentAction(
            title: '角色已更新',
            detail: '已将 ${updated.username} 调整为 ${updated.role}',
            changeType: _TenantMemberRecentActionType.role,
            changeLabel: '角色',
            beforeValue: _roleMeta(member.role).label,
            afterValue: _roleMeta(updated.role).label,
            createdAt: DateTime.now(),
          ),
        );
      });
      _focusMember(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${updated.username} 的角色为 ${updated.role}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新角色失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingMemberId = null;
        });
      }
    }
  }

  Future<void> _addMember() async {
    final tenantCode = _tenantCode;
    if (tenantCode.isEmpty) {
      return;
    }

    final created = await showDialog<_TenantMemberCreateResult>(
      context: context,
      builder: (_) =>
          _AddTenantMemberDialog(canGrantElevatedRoles: _canManageRoles),
    );
    if (created == null || !mounted) {
      return;
    }

    try {
      final member =
          await AppServices.instance.sessionRepository.addTenantMember(
        tenantCode: tenantCode,
        username: created.username,
        role: created.role,
        status: created.status,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _members = <TenantMemberSummary>[
          member,
          ..._members.where((entry) => entry.id != member.id),
        ];
        _recordRecentAction(
          member.id,
          _TenantMemberRecentAction(
            title: member.status == 'invited' ? '邀请已发送' : '成员已加入',
            detail: member.status == 'invited'
                ? '已邀请 ${member.username} 以 ${member.role} 身份加入当前租户'
                : '已将 ${member.username} 添加为 ${member.role}',
            changeType: member.status == 'invited'
                ? _TenantMemberRecentActionType.invitation
                : _TenantMemberRecentActionType.membership,
            changeLabel: member.status == 'invited' ? '加入方式' : '成员加入',
            afterValue: member.status == 'invited'
                ? '待加入'
                : _roleMeta(member.role).label,
            createdAt: DateTime.now(),
          ),
        );
      });
      _focusMember(member);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            member.status == 'invited'
                ? '已邀请 ${member.username} 以 ${member.role} 身份加入'
                : '已将 ${member.username} 添加为 ${member.role}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加成员失败：$error')),
      );
    }
  }

  Future<void> _updateStatus(
      TenantMemberSummary member, String nextStatus) async {
    setState(() {
      _updatingMemberId = member.id;
    });
    try {
      final updated =
          await AppServices.instance.sessionRepository.updateTenantMemberStatus(
        tenantCode: _tenantCode,
        memberId: member.id,
        status: nextStatus,
      );
      if (!mounted) {
        return;
      }
      TenantMemberSummary? nextQueueTarget;
      setState(() {
        final index = _members.indexWhere((entry) => entry.id == updated.id);
        if (index >= 0) {
          _members = <TenantMemberSummary>[
            ..._members.take(index),
            updated,
            ..._members.skip(index + 1),
          ];
        }
        _recordRecentAction(
          updated.id,
          _TenantMemberRecentAction(
            title: '状态已更新',
            detail:
                '已将 ${updated.username} 标记为 ${_statusMeta(updated.status).label}',
            changeType: _TenantMemberRecentActionType.status,
            changeLabel: '状态',
            beforeValue: _statusMeta(member.status).label,
            afterValue: _statusMeta(updated.status).label,
            createdAt: DateTime.now(),
          ),
        );
        nextQueueTarget = _syncActiveQueueAfterTargetMutation(updated.id);
      });
      _focusMember(nextQueueTarget ?? updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 ${updated.username} 标记为 ${updated.status}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新成员状态失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingMemberId = null;
        });
      }
    }
  }

  Future<void> _resendInvite(TenantMemberSummary member) async {
    setState(() {
      _updatingMemberId = member.id;
    });
    try {
      final updated =
          await AppServices.instance.sessionRepository.resendTenantMemberInvite(
        tenantCode: _tenantCode,
        memberId: member.id,
      );
      if (!mounted) {
        return;
      }
      TenantMemberSummary? nextQueueTarget;
      setState(() {
        final index = _members.indexWhere((entry) => entry.id == updated.id);
        if (index >= 0) {
          _members = <TenantMemberSummary>[
            ..._members.take(index),
            updated,
            ..._members.skip(index + 1),
          ];
        }
        _recordRecentAction(
          updated.id,
          _TenantMemberRecentAction(
            title: '邀请已重发',
            detail: '已重新向 ${updated.username} 发送加入邀请',
            changeType: _TenantMemberRecentActionType.invitation,
            changeLabel: '邀请状态',
            afterValue: '待加入',
            createdAt: DateTime.now(),
          ),
        );
        nextQueueTarget = _syncActiveQueueAfterTargetMutation(updated.id);
      });
      _focusMember(nextQueueTarget ?? updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重新发送 ${updated.username} 的邀请')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重新发送邀请失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingMemberId = null;
        });
      }
    }
  }

  Future<void> _removeMember(TenantMemberSummary member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: WorkspacePanel(
            borderRadius: 28,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '移除成员',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '确认将 ${member.username} 从当前租户移除吗？该操作会删除其成员关系。',
                  style: const TextStyle(
                    height: 1.5,
                    color: TelegramPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('确认移除'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _updatingMemberId = member.id;
    });
    try {
      await AppServices.instance.sessionRepository.removeTenantMember(
        tenantCode: _tenantCode,
        memberId: member.id,
      );
      if (!mounted) {
        return;
      }
      TenantMemberSummary? nextQueueTarget;
      setState(() {
        _members = _members.where((entry) => entry.id != member.id).toList();
        if (_focusedMemberId == member.id) {
          _focusedMemberId = null;
        }
        nextQueueTarget = _syncActiveQueueAfterTargetMutation(member.id);
      });
      if (nextQueueTarget != null) {
        _focusMember(nextQueueTarget!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除 ${member.username}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移除成员失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingMemberId = null;
        });
      }
    }
  }

  Future<void> _openMemberDetails(TenantMemberSummary member) async {
    List<TenantMemberAuditEvent> auditEvents = const <TenantMemberAuditEvent>[];
    try {
      auditEvents = await AppServices.instance.sessionRepository
          .listTenantMemberAuditEvents(
        tenantCode: _tenantCode,
        userId: member.userId,
      );
    } catch (_) {
      auditEvents = const <TenantMemberAuditEvent>[];
    }
    if (!mounted) {
      return;
    }
    final activeQueueMembers = _membersForActiveQueue().toList();
    final queueMemberIndex =
        activeQueueMembers.indexWhere((entry) => entry.id == member.id);
    final queuePriorityMember = _activeQueuePriorityMemberId == null
        ? null
        : activeQueueMembers.cast<TenantMemberSummary?>().firstWhere(
              (entry) => entry?.id == _activeQueuePriorityMemberId,
              orElse: () => null,
            );
    final queueNextMember = queueMemberIndex >= 0 &&
            queueMemberIndex + 1 < activeQueueMembers.length
        ? activeQueueMembers[queueMemberIndex + 1]
        : null;
    final result = await showModalBottomSheet<_TenantMemberActionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TenantMemberDetailsSheet(
        member: member,
        recentAction: _recentActions[member.id],
        history:
            _actionHistory[member.id] ?? const <_TenantMemberRecentAction>[],
        auditEvents: auditEvents,
        activeRole: _activeRole,
        activeUserId: _activeUserId,
        canManageRoles: _canManageRolesForMember(member),
        canManageStatuses: _canManageStatusForMember(member),
        canRemoveMembers: _canRemoveMemberForMember(member),
        activeQueueTitle: queueMemberIndex >= 0 ? _activeQueueTitle : null,
        activeQueueCompletionMessage:
            queueMemberIndex >= 0 ? _activeQueueCompletionMessage : null,
        queuePriorityMemberUsername: queuePriorityMember?.username,
        queueNextMemberUsername: queueNextMember?.username,
        memberIsPriorityTarget: member.id == _activeQueuePriorityMemberId,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    switch (result.kind) {
      case _TenantMemberActionKind.updateRole:
        await _updateRole(member, result.value!);
      case _TenantMemberActionKind.updateStatus:
        await _updateStatus(member, result.value!);
      case _TenantMemberActionKind.resendInvite:
        await _resendInvite(member);
      case _TenantMemberActionKind.remove:
        await _removeMember(member);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTenant = AppServices.instance.activeTenant;
    final visibleMembers = _visibleMembers;
    final visibleSections = _visibleSections;
    final activeRoleMeta = _roleMeta(activeTenant?.role ?? 'member');
    final activeUserMember = _activeUserMember;
    final activeQueueMembers = _membersForActiveQueue().toList();
    final activeQueuePriorityMember = _activeQueuePriorityMemberId == null
        ? null
        : activeQueueMembers.cast<TenantMemberSummary?>().firstWhere(
              (entry) => entry?.id == _activeQueuePriorityMemberId,
              orElse: () => null,
            );
    final activeQueueNextMember = activeQueuePriorityMember == null
        ? null
        : (() {
            final priorityIndex = activeQueueMembers.indexWhere(
              (member) => member.id == activeQueuePriorityMember.id,
            );
            if (priorityIndex >= 0 &&
                priorityIndex + 1 < activeQueueMembers.length) {
              return activeQueueMembers[priorityIndex + 1];
            }
            return null;
          })();
    final activeQueueSummary = _activeQueueTitle == null
        ? null
        : _tenantMemberQueueStatusSummary(
            completionMessage: _activeQueueCompletionMessage,
            priorityUsername: activeQueuePriorityMember?.username,
            nextMemberUsername: activeQueueNextMember?.username,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('成员与权限')),
      body: WorkspaceBackdrop(
        child: SafeArea(
          child: workspaceConstrainedContent(
            context,
            child: ListView(
              padding: workspacePagePadding(context),
              children: [
                WorkspacePanel(
                  padding: workspacePanelPadding(context),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(
                        label: '租户',
                        value: activeTenant?.name ?? '未选择租户',
                      ),
                      _InfoChip(label: '代码', value: activeTenant?.code ?? '-'),
                      _InfoChip(label: '当前角色', value: activeRoleMeta.label),
                      if (AppServices.instance.session?.username != null &&
                          AppServices.instance.session!.username.isNotEmpty)
                        _InfoChip(
                          label: '当前账号',
                          value: AppServices.instance.session!.username,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                WorkspacePanel(
                  padding: workspacePanelPadding(context),
                  borderRadius: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '成员与角色',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _canManageRoles
                            ? '你当前是${activeRoleMeta.label}，可以查看并调整租户成员角色。'
                            : '你当前是${activeRoleMeta.label}。可以查看成员，但不能修改角色。',
                        style: const TextStyle(
                          height: 1.5,
                          color: TelegramPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PermissionHintBanner(
                        activeRole: activeTenant?.role ?? 'member',
                        canAddMembers: _canAddMembers,
                        canManageRoles: _canManageRoles,
                        canManageStatuses: _canManageStatuses,
                        canRemoveMembers: _canRemoveMembers,
                      ),
                      if (activeUserMember != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _focusMember(activeUserMember),
                          icon: const Icon(Icons.my_location_outlined),
                          label: const Text('定位当前账号'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_canAddMembers) ...[
                        FilledButton.tonalIcon(
                          onPressed: _addMember,
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('添加成员'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wideDesktop = constraints.maxWidth >= 1180;
                          final quickViews = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '快速视图',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: TelegramPalette.textStrong,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  if (_activeUserMember != null)
                                    _TenantMemberQuickViewCard(
                                      label: '当前账号',
                                      value: '1',
                                      detail: '快速回到本人成员关系',
                                      icon: Icons.my_location_outlined,
                                      color: TelegramPalette.accentDark,
                                      onTap: () {
                                        _applyQuickView(
                                          statusFilter: 'all',
                                          scopeFilter: 'current_user',
                                        );
                                        _focusMember(_activeUserMember!);
                                      },
                                    ),
                                  _TenantMemberQuickViewCard(
                                    label: '待加入',
                                    value: _countByStatus('invited').toString(),
                                    detail: '优先处理邀请成员',
                                    icon: Icons.mark_email_unread_outlined,
                                    color: TelegramPalette.textStrong,
                                    onTap: () => _applyQuickView(
                                      statusFilter: 'invited',
                                      scopeFilter: 'all',
                                    ),
                                  ),
                                  _TenantMemberQuickViewCard(
                                    label: '已过期邀请',
                                    value: _expiredInviteCount.toString(),
                                    detail: '优先重发或撤销',
                                    icon: Icons.schedule_send_outlined,
                                    color: TelegramPalette.errorText,
                                    onTap: () => _applyQuickView(
                                      statusFilter: 'invited',
                                      scopeFilter: 'expired_invites',
                                    ),
                                  ),
                                  _TenantMemberQuickViewCard(
                                    label: '已重发邀请',
                                    value: _resentInviteCount.toString(),
                                    detail: '回看本轮已重发对象',
                                    icon: Icons.forward_to_inbox_outlined,
                                    color: TelegramPalette.accent,
                                    onTap: () => _applyQuickView(
                                      statusFilter: 'invited',
                                      scopeFilter: 'resent_invites',
                                    ),
                                  ),
                                  _TenantMemberQuickViewCard(
                                    label: '已停用',
                                    value:
                                        _countByStatus('disabled').toString(),
                                    detail: '查看待恢复成员',
                                    icon: Icons.pause_circle_outline,
                                    color: TelegramPalette.errorText,
                                    onTap: () => _applyQuickView(
                                      statusFilter: 'disabled',
                                      scopeFilter: 'all',
                                    ),
                                  ),
                                  _TenantMemberQuickViewCard(
                                    label: '可操作对象',
                                    value: _manageableCount.toString(),
                                    detail: '仅看当前可处理成员',
                                    icon: Icons.rule_folder_outlined,
                                    color: TelegramPalette.accent,
                                    onTap: () => _applyQuickView(
                                      statusFilter: 'all',
                                      scopeFilter: 'manageable',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                          final queueRail = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: TelegramPalette.highlight,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: TelegramPalette.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '邀请处理建议',
                                      style: TextStyle(
                                        color: TelegramPalette.textStrong,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._invitationRunbookLines.map(
                                      (line) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          line,
                                          style: const TextStyle(
                                            color: TelegramPalette.textMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: TelegramPalette.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: TelegramPalette.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '邀请处理队列',
                                      style: TextStyle(
                                        color: TelegramPalette.textStrong,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _TenantMemberQueueEntry(
                                      title: '优先处理已过期邀请',
                                      countLabel: '$_expiredInviteCount 位',
                                      detail: _queuePreview(
                                        _expiredInviteMembers,
                                        emptyLabel: '当前没有已过期邀请。',
                                      ),
                                      accentColor: TelegramPalette.errorText,
                                      icon: Icons.schedule_send_outlined,
                                      onTap: () => _applyQuickViewAndFocusFirst(
                                        statusFilter: 'invited',
                                        scopeFilter: 'expired_invites',
                                        queueKind: 'expired_invites',
                                        queueSectionKey: 'invited_expired',
                                        queueTitle: '优先处理已过期邀请',
                                        members: _expiredInviteMembers,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _TenantMemberQueueEntry(
                                      title: '继续跟进待加入成员',
                                      countLabel:
                                          '${_countByStatus('invited') - _expiredInviteCount} 位',
                                      detail: _queuePreview(
                                        _freshInviteMembers,
                                        emptyLabel: '当前没有仍在有效期内的待加入成员。',
                                      ),
                                      accentColor: TelegramPalette.accentDark,
                                      icon: Icons.mark_email_unread_outlined,
                                      onTap: () => _applyQuickViewAndFocusFirst(
                                        statusFilter: 'invited',
                                        scopeFilter: 'all',
                                        queueKind: 'fresh_invites',
                                        queueSectionKey: 'invited_valid',
                                        queueTitle: '继续跟进待加入成员',
                                        members: _freshInviteMembers,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _TenantMemberQueueEntry(
                                      title: '回看本轮已重发邀请',
                                      countLabel: '$_resentInviteCount 位',
                                      detail: _queuePreview(
                                        _resentInviteMembersList,
                                        emptyLabel: '当前没有本轮已重发邀请对象。',
                                      ),
                                      accentColor: TelegramPalette.accent,
                                      icon: Icons.forward_to_inbox_outlined,
                                      onTap: () => _applyQuickViewAndFocusFirst(
                                        statusFilter: 'invited',
                                        scopeFilter: 'resent_invites',
                                        queueKind: 'resent_invites',
                                        queueSectionKey: 'invited_valid',
                                        queueTitle: '回看本轮已重发邀请',
                                        members: _resentInviteMembersList,
                                      ),
                                    ),
                                    if (_activeQueueTitle != null &&
                                        activeQueueSummary != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: TelegramPalette.surfaceAccent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: TelegramPalette.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '当前处理队列 · $_activeQueueTitle',
                                              style: const TextStyle(
                                                color:
                                                    TelegramPalette.textStrong,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              activeQueueSummary.detail,
                                              style: const TextStyle(
                                                color:
                                                    TelegramPalette.textMuted,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                          if (!wideDesktop) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                quickViews,
                                const SizedBox(height: 16),
                                queueRail,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: quickViews),
                              const SizedBox(width: 20),
                              Expanded(flex: 5, child: queueRail),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '搜索成员',
                          hintText: '按用户名筛选',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _RoleFilterChip(
                            label: '全部',
                            selected: _roleFilter == 'all',
                            onTap: () => setState(() => _roleFilter = 'all'),
                          ),
                          _RoleFilterChip(
                            label: _roleMeta('owner').label,
                            selected: _roleFilter == 'owner',
                            onTap: () => setState(() => _roleFilter = 'owner'),
                          ),
                          _RoleFilterChip(
                            label: _roleMeta('admin').label,
                            selected: _roleFilter == 'admin',
                            onTap: () => setState(() => _roleFilter = 'admin'),
                          ),
                          _RoleFilterChip(
                            label: _roleMeta('member').label,
                            selected: _roleFilter == 'member',
                            onTap: () => setState(() => _roleFilter = 'member'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _RoleFilterChip(
                            label: '全部状态',
                            selected: _statusFilter == 'all',
                            onTap: () => setState(() => _statusFilter = 'all'),
                          ),
                          _RoleFilterChip(
                            label: '活跃',
                            selected: _statusFilter == 'active',
                            onTap: () =>
                                setState(() => _statusFilter = 'active'),
                          ),
                          _RoleFilterChip(
                            label: '待加入',
                            selected: _statusFilter == 'invited',
                            onTap: () =>
                                setState(() => _statusFilter = 'invited'),
                          ),
                          _RoleFilterChip(
                            label: '已停用',
                            selected: _statusFilter == 'disabled',
                            onTap: () =>
                                setState(() => _statusFilter = 'disabled'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _RoleFilterChip(
                            label: '全部对象',
                            selected: _scopeFilter == 'all',
                            onTap: () => setState(() => _scopeFilter = 'all'),
                          ),
                          _RoleFilterChip(
                            label: '仅看可操作',
                            selected: _scopeFilter == 'manageable',
                            onTap: () =>
                                setState(() => _scopeFilter = 'manageable'),
                          ),
                          _RoleFilterChip(
                            label: '仅看当前账号',
                            selected: _scopeFilter == 'current_user',
                            onTap: () =>
                                setState(() => _scopeFilter = 'current_user'),
                          ),
                          _RoleFilterChip(
                            label: '仅看过期邀请',
                            selected: _scopeFilter == 'expired_invites',
                            onTap: () => setState(
                                () => _scopeFilter = 'expired_invites'),
                          ),
                          _RoleFilterChip(
                            label: '仅看已重发邀请',
                            selected: _scopeFilter == 'resent_invites',
                            onTap: () =>
                                setState(() => _scopeFilter = 'resent_invites'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _sortMode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '排序',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'list', child: Text('列表顺序')),
                          DropdownMenuItem(
                              value: 'username', child: Text('按用户名')),
                          DropdownMenuItem(value: 'role', child: Text('按角色')),
                          DropdownMenuItem(value: 'status', child: Text('按状态')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _sortMode = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_activeFilterLabels.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _activeFilterLabels
                              .map(
                                (label) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TelegramPalette.surfaceAccent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: TelegramPalette.border),
                                  ),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: TelegramPalette.textStrong,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        '当前显示 ${visibleMembers.length} / ${_members.length} 位成员',
                        style: const TextStyle(
                          color: TelegramPalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: '全量活跃',
                            value: _countByStatus('active').toString(),
                          ),
                          _InfoChip(
                            label: '全量待加入',
                            value: _countByStatus('invited').toString(),
                          ),
                          _InfoChip(
                            label: '全量过期邀请',
                            value: _expiredInviteCount.toString(),
                          ),
                          _InfoChip(
                            label: '全量已重发',
                            value: _resentInviteCount.toString(),
                          ),
                          _InfoChip(
                            label: '全量已停用',
                            value: _countByStatus('disabled').toString(),
                          ),
                          if (_activeQueueTitle != null)
                            _InfoChip(label: '当前队列', value: _activeQueueTitle!),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _TenantMemberSummaryCard(
                            label: '当前活跃',
                            value: _visibleCountByStatus('active').toString(),
                            detail: '当前结果里可用成员',
                            color: TelegramPalette.accent,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前待加入',
                            value: _visibleCountByStatus('invited').toString(),
                            detail: '当前结果里待跟进成员',
                            color: TelegramPalette.textStrong,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前已停用',
                            value: _visibleCountByStatus('disabled').toString(),
                            detail: '当前结果里待恢复成员',
                            color: TelegramPalette.errorText,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前可操作',
                            value: _visibleManageableCount.toString(),
                            detail: '当前结果里可继续处理的成员',
                            color: TelegramPalette.accentDark,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前账号',
                            value: _visibleIncludesActiveUser ? '已包含' : '已隐藏',
                            detail: '当前结果里的本人成员关系',
                            color: TelegramPalette.textStrong,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前过期邀请',
                            value: _visibleExpiredInviteCount.toString(),
                            detail: '当前结果里优先重发或撤销',
                            color: TelegramPalette.errorText,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前已重发',
                            value: _visibleResentInviteCount.toString(),
                            detail: '当前结果里可回看本轮对象',
                            color: TelegramPalette.accent,
                          ),
                          _TenantMemberSummaryCard(
                            label: '当前有效邀请',
                            value: _visibleFreshInviteCount.toString(),
                            detail: '当前结果里仍在有效期内',
                            color: TelegramPalette.accentDark,
                          ),
                          _TenantMemberSummaryCard(
                            label: _roleMeta('owner').shortLabel,
                            value: _visibleCountByRole('owner').toString(),
                            detail: '当前结果里的所有者',
                            color: TelegramPalette.accentDark,
                          ),
                          _TenantMemberSummaryCard(
                            label: _roleMeta('admin').shortLabel,
                            value: _visibleCountByRole('admin').toString(),
                            detail: '当前结果里的管理角色',
                            color: TelegramPalette.accent,
                          ),
                          _TenantMemberSummaryCard(
                            label: _roleMeta('member').shortLabel,
                            value: _visibleCountByRole('member').toString(),
                            detail: '当前结果里的普通成员',
                            color: TelegramPalette.textStrong,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _TenantMemberSummaryCard(
                            label: _roleMeta('owner').shortLabel,
                            value: _countByRole('owner').toString(),
                            detail: '高权限角色',
                            color: TelegramPalette.accentDark,
                          ),
                          _TenantMemberSummaryCard(
                            label: _roleMeta('admin').shortLabel,
                            value: _countByRole('admin').toString(),
                            detail: '租户维护',
                            color: TelegramPalette.accent,
                          ),
                          _TenantMemberSummaryCard(
                            label: 'Active',
                            value: _countByStatus('active').toString(),
                            detail: '当前可用',
                            color: TelegramPalette.accent,
                          ),
                          _TenantMemberSummaryCard(
                            label: 'Invited',
                            value: _countByStatus('invited').toString(),
                            detail: '待加入',
                            color: TelegramPalette.textStrong,
                          ),
                          _TenantMemberSummaryCard(
                            label: 'Expired',
                            value: _expiredInviteCount.toString(),
                            detail: '已过期邀请',
                            color: TelegramPalette.errorText,
                          ),
                          _TenantMemberSummaryCard(
                            label: 'Resent',
                            value: _resentInviteCount.toString(),
                            detail: '本轮已重发',
                            color: TelegramPalette.accent,
                          ),
                          _TenantMemberSummaryCard(
                            label: 'Disabled',
                            value: _countByStatus('disabled').toString(),
                            detail: '已停用',
                            color: TelegramPalette.errorText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '成员加载失败：$_error',
                              style: const TextStyle(
                                  color: TelegramPalette.errorText),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重新加载'),
                            ),
                          ],
                        )
                      else if (_members.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '当前租户还没有可显示的成员。',
                              style:
                                  TextStyle(color: TelegramPalette.textMuted),
                            ),
                            if (_canAddMembers) ...[
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: _addMember,
                                icon:
                                    const Icon(Icons.person_add_alt_1_outlined),
                                label: const Text('添加第一位成员'),
                              ),
                            ],
                          ],
                        )
                      else if (visibleMembers.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '没有符合当前搜索或筛选条件的成员。',
                              style:
                                  TextStyle(color: TelegramPalette.textMuted),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('恢复默认视图'),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: visibleSections
                              .map(
                                (section) => Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _TenantMemberSectionCard(
                                    section: section,
                                    recentActions: _recentActions,
                                    focusedMemberId: _focusedMemberId,
                                    activeQueueSectionKey:
                                        _activeQueueSectionKey,
                                    activeQueueTitle: _activeQueueTitle,
                                    activeQueuePriorityMemberId:
                                        _activeQueuePriorityMemberId,
                                    activeQueueCompletionMessage:
                                        _activeQueueCompletionMessage,
                                    memberCardKeyForId: _keyForMember,
                                    onFocusSection: () => _applyQuickView(
                                      statusFilter: section.filterStatus,
                                      scopeFilter: section.filterScope,
                                    ),
                                    onFocusManageableInSection: () =>
                                        _applyQuickView(
                                      statusFilter: section.filterStatus,
                                      scopeFilter: section.filterScope ==
                                              'expired_invites'
                                          ? 'manageable_expired_invites'
                                          : 'manageable',
                                    ),
                                    activeRole: _activeRole,
                                    activeUserId: _activeUserId,
                                    canManageRolesForMember:
                                        _canManageRolesForMember,
                                    canManageStatusesForMember:
                                        _canManageStatusForMember,
                                    canRemoveMembersForMember:
                                        _canRemoveMemberForMember,
                                    updatingMemberId: _updatingMemberId,
                                    onRoleChanged: _updateRole,
                                    onStatusChanged: _updateStatus,
                                    onRemove: _removeMember,
                                    onOpenDetails: _openMemberDetails,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRouter.tenantSwitch),
                        icon: const Icon(Icons.apartment_outlined),
                        label: const Text('返回租户切换'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionHintBanner extends StatelessWidget {
  const _PermissionHintBanner({
    required this.activeRole,
    required this.canAddMembers,
    required this.canManageRoles,
    required this.canManageStatuses,
    required this.canRemoveMembers,
  });

  final String activeRole;
  final bool canAddMembers;
  final bool canManageRoles;
  final bool canManageStatuses;
  final bool canRemoveMembers;

  @override
  Widget build(BuildContext context) {
    final activeRoleMeta = _roleMeta(activeRole);
    final hintLines = <String>[
      if (canAddMembers) '你可以把已有账号加入当前租户。' else '你当前不能添加成员。',
      if (canAddMembers) '你也可以先发送邀请，让对方自行完成加入。' else '邀请成员同样需要管理员或所有者权限。',
      if (canManageRoles) '你可以把成员调整为成员 / 管理员 / 所有者。' else '只有所有者可以调整成员角色。',
      if (canManageStatuses)
        '你可以停用普通成员；只有所有者可以停用或恢复管理员 / 所有者。'
      else
        '你当前不能调整成员状态。',
      if (canRemoveMembers) '你可以移除普通成员；只有所有者可以移除管理员 / 所有者。' else '你当前不能移除成员。',
    ];
    return WorkspaceMessageBanner.info(
      title: '当前租户角色：${activeRoleMeta.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hintLines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: TelegramPalette.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WorkspaceFilterPill(
      label: label,
      selected: selected,
      onTap: onTap,
      showSelectedCheckmark: true,
    );
  }
}

class _TenantMemberCreateResult {
  const _TenantMemberCreateResult({
    required this.username,
    required this.role,
    required this.status,
  });

  final String username;
  final String role;
  final String status;
}

class _TenantMemberSection {
  const _TenantMemberSection({
    required this.sectionKey,
    required this.status,
    required this.filterStatus,
    required this.filterScope,
    required this.label,
    required this.hint,
    required this.members,
  });

  final String sectionKey;
  final String status;
  final String filterStatus;
  final String filterScope;
  final String label;
  final String hint;
  final List<TenantMemberSummary> members;
}

class _TenantMemberSummaryCard extends StatelessWidget {
  const _TenantMemberSummaryCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TelegramPalette.surfaceAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TelegramPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(
              color: TelegramPalette.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantMemberQuickViewCard extends StatelessWidget {
  const _TenantMemberQuickViewCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 182,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TelegramPalette.surfaceAccent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TelegramPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: TelegramPalette.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                color: TelegramPalette.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantMemberQueueEntry extends StatelessWidget {
  const _TenantMemberQueueEntry({
    required this.title,
    required this.countLabel,
    required this.detail,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String countLabel;
  final String detail;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TelegramPalette.highlight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TelegramPalette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: TelegramPalette.textStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        countLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: TelegramPalette.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantMemberRecentAction {
  const _TenantMemberRecentAction({
    required this.title,
    required this.detail,
    this.changeType,
    this.changeLabel,
    this.beforeValue,
    this.afterValue,
    required this.createdAt,
  });

  final String title;
  final String detail;
  final _TenantMemberRecentActionType? changeType;
  final String? changeLabel;
  final String? beforeValue;
  final String? afterValue;
  final DateTime createdAt;

  String get createdAtLabel {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

enum _TenantMemberRecentActionType {
  role,
  status,
  invitation,
  membership,
}

class _TenantMemberRecentActionMeta {
  const _TenantMemberRecentActionMeta({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

_TenantMemberRecentActionMeta _recentActionMeta(
  _TenantMemberRecentActionType? type,
) {
  return switch (type) {
    _TenantMemberRecentActionType.role => const _TenantMemberRecentActionMeta(
        backgroundColor: TelegramPalette.surfaceAccent,
        foregroundColor: TelegramPalette.accentDark,
      ),
    _TenantMemberRecentActionType.status => const _TenantMemberRecentActionMeta(
        backgroundColor: TelegramPalette.errorSurface,
        foregroundColor: TelegramPalette.errorText,
      ),
    _TenantMemberRecentActionType.invitation =>
      const _TenantMemberRecentActionMeta(
        backgroundColor: TelegramPalette.highlight,
        foregroundColor: TelegramPalette.textStrong,
      ),
    _TenantMemberRecentActionType.membership =>
      const _TenantMemberRecentActionMeta(
        backgroundColor: TelegramPalette.surfaceAccent,
        foregroundColor: TelegramPalette.textStrong,
      ),
    null => const _TenantMemberRecentActionMeta(
        backgroundColor: TelegramPalette.surfaceAccent,
        foregroundColor: TelegramPalette.accentDark,
      ),
  };
}

class _AddTenantMemberDialog extends StatefulWidget {
  const _AddTenantMemberDialog({
    required this.canGrantElevatedRoles,
  });

  final bool canGrantElevatedRoles;

  @override
  State<_AddTenantMemberDialog> createState() => _AddTenantMemberDialogState();
}

class _AddTenantMemberDialogState extends State<_AddTenantMemberDialog> {
  final _usernameController = TextEditingController();
  String _role = 'member';
  String _status = 'active';

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleOptions = widget.canGrantElevatedRoles
        ? const <String>['member', 'admin', 'owner']
        : const <String>['member'];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: WorkspacePanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '添加租户成员',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '输入系统里已存在的用户名，把该账号加入当前租户。',
                style: TextStyle(
                  height: 1.5,
                  color: TelegramPalette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '例如：teacher_zhang',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                items: roleOptions
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(_roleMeta(role).label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _role = value;
                  });
                },
                decoration: const InputDecoration(labelText: '加入角色'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('直接加入')),
                  DropdownMenuItem(value: 'invited', child: Text('发送邀请')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _status = value;
                  });
                },
                decoration: const InputDecoration(labelText: '加入方式'),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final username = _usernameController.text.trim();
                        if (username.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pop(
                          _TenantMemberCreateResult(
                            username: username,
                            role: _role,
                            status: _status,
                          ),
                        );
                      },
                      child: const Text('添加成员'),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
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
        color: TelegramPalette.surfaceAccent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label：$value',
        style: const TextStyle(
          color: TelegramPalette.textStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TenantInvitationGuidance {
  const _TenantInvitationGuidance({
    required this.title,
    required this.detail,
    required this.prioritizeResend,
    required this.showWaitCard,
  });

  final String title;
  final String detail;
  final bool prioritizeResend;
  final bool showWaitCard;
}

_TenantInvitationGuidance? _tenantInvitationGuidance({
  required TenantMemberSummary member,
  _TenantMemberRecentAction? recentAction,
  List<_TenantMemberRecentAction> history = const <_TenantMemberRecentAction>[],
}) {
  if (member.status != 'invited') {
    return null;
  }
  final wasRecentlyResent = recentAction?.title == '邀请已重发' ||
      history.any((entry) => entry.title == '邀请已重发');
  if (member.isInvitationExpired) {
    return const _TenantInvitationGuidance(
      title: '建议优先重发邀请',
      detail: '这次邀请已经过期，优先重新发送邀请；需要立刻生效时再直接激活成员。',
      prioritizeResend: true,
      showWaitCard: false,
    );
  }
  if (wasRecentlyResent) {
    return const _TenantInvitationGuidance(
      title: '本轮已重发邀请',
      detail: '建议先等待对方完成加入，再决定是否直接激活。',
      prioritizeResend: false,
      showWaitCard: true,
    );
  }
  return const _TenantInvitationGuidance(
    title: '当前建议',
    detail: '这次邀请仍有效，建议先等待对方自行加入，再决定下一步怎么处理。',
    prioritizeResend: false,
    showWaitCard: false,
  );
}

class _TenantMemberQueueStatusSummary {
  const _TenantMemberQueueStatusSummary({
    required this.badgeLabel,
    required this.detail,
    required this.isComplete,
  });

  final String badgeLabel;
  final String detail;
  final bool isComplete;
}

_TenantMemberQueueStatusSummary _tenantMemberQueueStatusSummary({
  String? completionMessage,
  String? priorityUsername,
  String? nextMemberUsername,
  bool memberIsPriorityTarget = false,
  bool memberIsInQueue = false,
}) {
  if (completionMessage != null) {
    return _TenantMemberQueueStatusSummary(
      badgeLabel: '本轮已处理完成',
      detail: completionMessage,
      isComplete: true,
    );
  }
  if (memberIsPriorityTarget) {
    return _TenantMemberQueueStatusSummary(
      badgeLabel: '当前处理队列',
      detail: nextMemberUsername == null
          ? '当前成员就是这条处理队列里的优先对象。'
          : '当前成员就是这条处理队列里的优先对象。下一处理对象：$nextMemberUsername。',
      isComplete: false,
    );
  }
  if (memberIsInQueue) {
    return _TenantMemberQueueStatusSummary(
      badgeLabel: '当前处理队列',
      detail: priorityUsername == null
          ? '当前成员属于这条处理队列，可继续按队列顺序推进。'
          : '当前成员属于这条处理队列，可继续按队列顺序推进。当前优先对象：$priorityUsername。',
      isComplete: false,
    );
  }
  if (priorityUsername != null && nextMemberUsername != null) {
    return _TenantMemberQueueStatusSummary(
      badgeLabel: '当前处理队列',
      detail: '当前优先对象：$priorityUsername。下一处理对象：$nextMemberUsername。',
      isComplete: false,
    );
  }
  if (priorityUsername != null) {
    return _TenantMemberQueueStatusSummary(
      badgeLabel: '当前处理队列',
      detail: '当前优先对象：$priorityUsername。',
      isComplete: false,
    );
  }
  return const _TenantMemberQueueStatusSummary(
    badgeLabel: '当前处理队列',
    detail: '当前没有可聚焦的优先对象。',
    isComplete: false,
  );
}

class _TenantInvitationLifecycleSummary {
  const _TenantInvitationLifecycleSummary({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;
}

_TenantInvitationLifecycleSummary? _tenantInvitationLifecycleSummary({
  required TenantMemberSummary member,
  _TenantMemberRecentAction? recentAction,
  List<_TenantMemberRecentAction> history = const <_TenantMemberRecentAction>[],
}) {
  if (member.status != 'invited') {
    return null;
  }
  final guidance = _tenantInvitationGuidance(
    member: member,
    recentAction: recentAction,
    history: history,
  );
  if (member.isInvitationExpired) {
    return const _TenantInvitationLifecycleSummary(
      label: '已过期待处理',
      detail: '当前更适合重发邀请或撤销这次待加入关系。',
      color: TelegramPalette.errorText,
    );
  }
  if (guidance?.showWaitCard == true) {
    return const _TenantInvitationLifecycleSummary(
      label: '已重发待回看',
      detail: '本轮已重发邀请，先等待对方自助加入，再决定是否直接激活。',
      color: TelegramPalette.accent,
    );
  }
  return const _TenantInvitationLifecycleSummary(
    label: '等待自助加入',
    detail: '邀请仍有效，优先等待对方完成加入。',
    color: TelegramPalette.accentDark,
  );
}

class _TenantInvitationResolutionSummary {
  const _TenantInvitationResolutionSummary({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;
}

_TenantInvitationResolutionSummary? _tenantInvitationResolutionSummary({
  required TenantMemberSummary member,
  _TenantMemberRecentAction? recentAction,
  List<_TenantMemberRecentAction> history = const <_TenantMemberRecentAction>[],
}) {
  if (member.status != 'active') {
    return null;
  }
  final actions = <_TenantMemberRecentAction>[
    if (recentAction != null) recentAction,
    ...history,
  ];
  final activatedFromInvite = actions.any(
    (entry) =>
        entry.changeType == _TenantMemberRecentActionType.status &&
        entry.beforeValue == '待加入' &&
        entry.afterValue == '活跃',
  );
  if (!activatedFromInvite) {
    return null;
  }
  return const _TenantInvitationResolutionSummary(
    label: '邀请已完成',
    detail: '该成员已经从待加入状态完成激活，当前邀请流程已收口。',
    color: TelegramPalette.accentDark,
  );
}

String _tenantMemberStatusNarrative({
  required TenantMemberSummary member,
  _TenantInvitationLifecycleSummary? invitationLifecycle,
  _TenantInvitationResolutionSummary? invitationResolution,
  required bool concise,
}) {
  final base = switch (member.status) {
    'invited' => concise
        ? member.isInvitationExpired
            ? '该账号的邀请已过期，建议重新发送邀请或直接激活成员关系。'
            : '该账号已收到邀请，等待自行加入或由管理员直接激活。'
        : member.isInvitationExpired
            ? '该成员当前仍处于邀请态，但这次邀请已经过期。你可以重新发送邀请，直接激活成员关系，或撤销当前邀请。'
            : '该成员当前仍处于邀请态。你可以直接激活成员关系，重新发送邀请，或撤销当前邀请。',
    'disabled' =>
      concise ? '该账号当前无法访问当前租户，可恢复或移除。' : '该成员当前已被停用。恢复后会重新获得当前租户访问权限。',
    _ =>
      concise ? '该账号当前处于活跃状态，可继续参与当前租户。' : '该成员当前处于正常可用状态。你可以调整角色、停用，或将其移出租户。',
  };
  if (invitationResolution != null) {
    return '$base ${invitationResolution.detail}';
  }
  if (invitationLifecycle != null) {
    return '$base ${invitationLifecycle.detail}';
  }
  return base;
}

class _TenantMemberCard extends StatelessWidget {
  const _TenantMemberCard({
    super.key,
    required this.member,
    required this.recentAction,
    required this.focused,
    required this.activeRole,
    required this.activeUserId,
    required this.canManageRoles,
    required this.canManageStatuses,
    required this.canRemoveMembers,
    required this.activeQueueTitle,
    required this.activeQueueCompletionMessage,
    required this.memberIsPriorityTarget,
    required this.nextQueueMemberUsername,
    required this.updating,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onRemove,
    required this.onOpenDetails,
  });

  final TenantMemberSummary member;
  final _TenantMemberRecentAction? recentAction;
  final bool focused;
  final String activeRole;
  final String activeUserId;
  final bool canManageRoles;
  final bool canManageStatuses;
  final bool canRemoveMembers;
  final String? activeQueueTitle;
  final String? activeQueueCompletionMessage;
  final bool memberIsPriorityTarget;
  final String? nextQueueMemberUsername;
  final bool updating;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRemove;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusMeta(member.status);
    final roleMeta = _roleMeta(member.role);
    final invitationGuidance = _tenantInvitationGuidance(
      member: member,
      recentAction: recentAction,
    );
    final invitationLifecycle = _tenantInvitationLifecycleSummary(
      member: member,
      recentAction: recentAction,
    );
    final invitationResolution = _tenantInvitationResolutionSummary(
      member: member,
      recentAction: recentAction,
    );
    final queueSummary = activeQueueTitle == null
        ? null
        : _tenantMemberQueueStatusSummary(
            completionMessage: activeQueueCompletionMessage,
            memberIsPriorityTarget: memberIsPriorityTarget,
            memberIsInQueue: focused,
            nextMemberUsername: nextQueueMemberUsername,
          );
    final statusActionLabel = switch (member.status) {
      'invited' => '激活成员',
      'active' => '停用成员',
      _ => '重新启用',
    };
    final invitationStateLabel = member.isInvitationExpired ? '邀请已过期' : '邀请仍有效';
    final removeLabel = member.status == 'invited' ? '撤销邀请' : '移除成员';
    final statusHint = _tenantMemberStatusNarrative(
      member: member,
      invitationLifecycle: invitationLifecycle,
      invitationResolution: invitationResolution,
      concise: true,
    );
    final emphasizePrimaryAction = member.status != 'active';
    final lockedReasonLines = _tenantMemberLockedReasons(
      member: member,
      activeRole: activeRole,
      activeUserId: activeUserId,
      canManageRoles: canManageRoles,
      canManageStatuses: canManageStatuses,
      canRemoveMembers: canRemoveMembers,
    );
    final isReadOnly =
        !canManageRoles && !canManageStatuses && !canRemoveMembers;
    final queueContextVisible =
        activeQueueTitle != null && (memberIsPriorityTarget || focused);
    final isCurrentUser = member.userId == activeUserId;
    return WorkspacePanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 16,
      backgroundColor: focused
          ? TelegramPalette.surfaceAccent
          : TelegramPalette.surfaceRaised,
      borderColor:
          focused ? TelegramPalette.borderAccent : TelegramPalette.border,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: TelegramPalette.surfaceAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_outline,
                color: TelegramPalette.accentDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.username,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TelegramPalette.surfaceAccent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: const Text(
                      '当前账号',
                      style: TextStyle(
                        color: TelegramPalette.accentDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (focused) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '当前聚焦成员',
                    style: TextStyle(
                      color: TelegramPalette.accentDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${roleMeta.label} · ${member.createdAtLabel}',
                      style: const TextStyle(color: TelegramPalette.textSoft),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusMeta.backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusMeta.label,
                        style: TextStyle(
                          color: statusMeta.foregroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (member.status == 'invited')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: member.isInvitationExpired
                              ? TelegramPalette.errorSurface
                              : TelegramPalette.highlight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          invitationStateLabel,
                          style: TextStyle(
                            color: member.isInvitationExpired
                                ? TelegramPalette.errorText
                                : TelegramPalette.textStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (invitationLifecycle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TelegramPalette.surfaceAccent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: TelegramPalette.border),
                        ),
                        child: Text(
                          invitationLifecycle.label,
                          style: TextStyle(
                            color: invitationLifecycle.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (invitationResolution != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TelegramPalette.surfaceAccent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: TelegramPalette.border),
                        ),
                        child: Text(
                          invitationResolution.label,
                          style: TextStyle(
                            color: invitationResolution.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusHint,
                  style: const TextStyle(
                    color: TelegramPalette.textMuted,
                    height: 1.35,
                  ),
                ),
                if (invitationGuidance != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: member.isInvitationExpired
                          ? TelegramPalette.errorSurface
                          : TelegramPalette.highlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitationGuidance.title,
                          style: TextStyle(
                            color: member.isInvitationExpired
                                ? TelegramPalette.errorText
                                : TelegramPalette.accentDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invitationGuidance.detail,
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (queueContextVisible && queueSummary != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TelegramPalette.surfaceAccent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前处理队列 · $activeQueueTitle',
                          style: const TextStyle(
                            color: TelegramPalette.accentDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          queueSummary.detail,
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isReadOnly && lockedReasonLines.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TelegramPalette.errorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前为只读对象',
                          style: TextStyle(
                            color: TelegramPalette.errorText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lockedReasonLines.first,
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (recentAction != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TelegramPalette.highlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TelegramPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${recentAction!.title} · ${recentAction!.createdAtLabel}',
                          style: const TextStyle(
                            color: TelegramPalette.accentDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recentAction!.detail,
                          style: const TextStyle(
                            color: TelegramPalette.textMuted,
                            height: 1.35,
                          ),
                        ),
                        if (recentAction!.changeLabel != null &&
                            recentAction!.afterValue != null) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (_) {
                              final changeMeta = _recentActionMeta(
                                recentAction!.changeType,
                              );
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: changeMeta.backgroundColor,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: TelegramPalette.border),
                                    ),
                                    child: Text(
                                      recentAction!.beforeValue == null
                                          ? '${recentAction!.changeLabel}：${recentAction!.afterValue}'
                                          : '${recentAction!.changeLabel}：${recentAction!.beforeValue} → ${recentAction!.afterValue}',
                                      style: TextStyle(
                                        color: changeMeta.foregroundColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (canManageRoles)
                DropdownButton<String>(
                  value: member.role,
                  onChanged: updating
                      ? null
                      : (value) {
                          if (value == null || value == member.role) {
                            return;
                          }
                          onRoleChanged(value);
                        },
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('成员')),
                    DropdownMenuItem(value: 'admin', child: Text('管理员')),
                    DropdownMenuItem(value: 'owner', child: Text('所有者')),
                  ],
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: TelegramPalette.highlight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    roleMeta.label,
                    style: const TextStyle(
                      color: TelegramPalette.accentDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (canManageStatuses)
                (emphasizePrimaryAction
                    ? FilledButton.tonal(
                        onPressed: updating
                            ? null
                            : () => onStatusChanged(
                                  member.status == 'active'
                                      ? 'disabled'
                                      : 'active',
                                ),
                        child: Text(statusActionLabel),
                      )
                    : OutlinedButton(
                        onPressed: updating
                            ? null
                            : () => onStatusChanged(
                                  member.status == 'active'
                                      ? 'disabled'
                                      : 'active',
                                ),
                        child: Text(statusActionLabel),
                      )),
              if (canRemoveMembers) ...[
                const SizedBox(height: 8),
                if (member.status == 'invited')
                  OutlinedButton(
                    onPressed: updating ? null : onRemove,
                    child: Text(removeLabel),
                  )
                else
                  TextButton(
                    onPressed: updating ? null : onRemove,
                    child: Text(removeLabel),
                  ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: updating ? null : onOpenDetails,
                child: const Text('查看详情'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TenantMemberSectionCard extends StatelessWidget {
  const _TenantMemberSectionCard({
    required this.section,
    required this.recentActions,
    required this.focusedMemberId,
    required this.activeQueueSectionKey,
    required this.activeQueueTitle,
    required this.activeQueuePriorityMemberId,
    required this.activeQueueCompletionMessage,
    required this.memberCardKeyForId,
    required this.onFocusSection,
    required this.onFocusManageableInSection,
    required this.activeRole,
    required this.activeUserId,
    required this.canManageRolesForMember,
    required this.canManageStatusesForMember,
    required this.canRemoveMembersForMember,
    required this.updatingMemberId,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onRemove,
    required this.onOpenDetails,
  });

  final _TenantMemberSection section;
  final Map<String, _TenantMemberRecentAction> recentActions;
  final String? focusedMemberId;
  final String? activeQueueSectionKey;
  final String? activeQueueTitle;
  final String? activeQueuePriorityMemberId;
  final String? activeQueueCompletionMessage;
  final GlobalKey Function(String memberId) memberCardKeyForId;
  final VoidCallback onFocusSection;
  final VoidCallback onFocusManageableInSection;
  final String activeRole;
  final String activeUserId;
  final bool Function(TenantMemberSummary member) canManageRolesForMember;
  final bool Function(TenantMemberSummary member) canManageStatusesForMember;
  final bool Function(TenantMemberSummary member) canRemoveMembersForMember;
  final String? updatingMemberId;
  final Future<void> Function(TenantMemberSummary member, String nextRole)
      onRoleChanged;
  final Future<void> Function(TenantMemberSummary member, String nextStatus)
      onStatusChanged;
  final Future<void> Function(TenantMemberSummary member) onRemove;
  final Future<void> Function(TenantMemberSummary member) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusMeta(section.status);
    final queueFocused = activeQueueSectionKey == section.sectionKey;
    TenantMemberSummary? priorityMember;
    if (activeQueuePriorityMemberId != null) {
      for (final member in section.members) {
        if (member.id == activeQueuePriorityMemberId) {
          priorityMember = member;
          break;
        }
      }
    }
    final manageableCount = section.members
        .where(
          (member) =>
              canManageRolesForMember(member) ||
              canManageStatusesForMember(member) ||
              canRemoveMembersForMember(member),
        )
        .length;
    String? nextPriorityMemberUsername;
    if (queueFocused && priorityMember != null) {
      final priorityIndex = section.members.indexWhere(
        (member) => member.id == priorityMember!.id,
      );
      if (priorityIndex >= 0 && priorityIndex + 1 < section.members.length) {
        nextPriorityMemberUsername =
            section.members[priorityIndex + 1].username;
      }
    }
    final queueSummary = queueFocused && activeQueueTitle != null
        ? _tenantMemberQueueStatusSummary(
            completionMessage: activeQueueCompletionMessage,
            priorityUsername: priorityMember?.username,
            nextMemberUsername: nextPriorityMemberUsername,
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusMeta.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: queueFocused
                  ? TelegramPalette.borderAccent
                  : TelegramPalette.border,
              width: queueFocused ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                section.label,
                style: TextStyle(
                  color: statusMeta.foregroundColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${section.members.length} 位成员',
                style: const TextStyle(
                  color: TelegramPalette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (queueFocused && queueSummary != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: queueSummary.isComplete
                        ? TelegramPalette.surfaceAccent
                        : TelegramPalette.highlight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: TelegramPalette.border),
                  ),
                  child: Text(
                    queueSummary.badgeLabel,
                    style: TextStyle(
                      color: queueSummary.isComplete
                          ? TelegramPalette.textStrong
                          : TelegramPalette.accentDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: onFocusSection,
                child: const Text('聚焦本组'),
              ),
              if (manageableCount > 0)
                TextButton(
                  onPressed: onFocusManageableInSection,
                  child: Text('可处理 $manageableCount'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          section.hint,
          style: const TextStyle(
            color: TelegramPalette.textMuted,
            height: 1.4,
          ),
        ),
        if (queueFocused &&
            activeQueueTitle != null &&
            queueSummary != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TelegramPalette.highlight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TelegramPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前处理队列 · $activeQueueTitle',
                  style: const TextStyle(
                    color: TelegramPalette.accentDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  queueSummary.detail,
                  style: const TextStyle(
                    color: TelegramPalette.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...section.members.map(
          (member) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TenantMemberCard(
              key: memberCardKeyForId(member.id),
              member: member,
              recentAction: recentActions[member.id],
              focused: focusedMemberId == member.id,
              activeRole: activeRole,
              activeUserId: activeUserId,
              canManageRoles: canManageRolesForMember(member),
              canManageStatuses: canManageStatusesForMember(member),
              canRemoveMembers: canRemoveMembersForMember(member),
              activeQueueTitle: queueFocused ? activeQueueTitle : null,
              activeQueueCompletionMessage:
                  queueFocused ? activeQueueCompletionMessage : null,
              memberIsPriorityTarget: member.id == activeQueuePriorityMemberId,
              nextQueueMemberUsername: member.id == activeQueuePriorityMemberId
                  ? nextPriorityMemberUsername
                  : null,
              updating: updatingMemberId == member.id,
              onRoleChanged: (role) => onRoleChanged(member, role),
              onStatusChanged: (status) => onStatusChanged(member, status),
              onRemove: () => onRemove(member),
              onOpenDetails: () => onOpenDetails(member),
            ),
          ),
        ),
      ],
    );
  }
}

enum _TenantMemberActionKind {
  updateRole,
  updateStatus,
  resendInvite,
  remove,
}

class _TenantMemberActionResult {
  const _TenantMemberActionResult({
    required this.kind,
    this.value,
  });

  final _TenantMemberActionKind kind;
  final String? value;
}

class _TenantMemberDetailsSheet extends StatelessWidget {
  const _TenantMemberDetailsSheet({
    required this.member,
    required this.recentAction,
    required this.history,
    required this.auditEvents,
    required this.activeRole,
    required this.activeUserId,
    required this.canManageRoles,
    required this.canManageStatuses,
    required this.canRemoveMembers,
    required this.activeQueueTitle,
    required this.activeQueueCompletionMessage,
    required this.queuePriorityMemberUsername,
    required this.queueNextMemberUsername,
    required this.memberIsPriorityTarget,
  });

  final TenantMemberSummary member;
  final _TenantMemberRecentAction? recentAction;
  final List<_TenantMemberRecentAction> history;
  final List<TenantMemberAuditEvent> auditEvents;
  final String activeRole;
  final String activeUserId;
  final bool canManageRoles;
  final bool canManageStatuses;
  final bool canRemoveMembers;
  final String? activeQueueTitle;
  final String? activeQueueCompletionMessage;
  final String? queuePriorityMemberUsername;
  final String? queueNextMemberUsername;
  final bool memberIsPriorityTarget;

  @override
  Widget build(BuildContext context) {
    final statusMeta = _statusMeta(member.status);
    final roleMeta = _roleMeta(member.role);
    final invitationGuidance = _tenantInvitationGuidance(
      member: member,
      recentAction: recentAction,
      history: history,
    );
    final invitationLifecycle = _tenantInvitationLifecycleSummary(
      member: member,
      recentAction: recentAction,
      history: history,
    );
    final invitationResolution = _tenantInvitationResolutionSummary(
      member: member,
      recentAction: recentAction,
      history: history,
    );
    final prioritizeResend = invitationGuidance?.prioritizeResend ?? false;
    final statusActionLabel = switch (member.status) {
      'invited' => '激活成员',
      'active' => '停用成员',
      _ => '重新启用',
    };
    final statusHint = _tenantMemberStatusNarrative(
      member: member,
      invitationLifecycle: invitationLifecycle,
      invitationResolution: invitationResolution,
      concise: false,
    );
    final removeLabel = member.status == 'invited' ? '撤销邀请' : '移除成员';
    final primaryActionDetail = switch (member.status) {
      'invited' => '把待加入成员直接转为当前租户可用账号。',
      'disabled' => '恢复该成员在当前租户中的访问权限。',
      _ => '暂停该成员继续访问当前租户。',
    };
    final removeDetail = switch (member.status) {
      'invited' => '撤销这次尚未完成的邀请，不再保留待加入关系。',
      _ => '把该成员从当前租户彻底移除。',
    };
    final resendDetail = member.isInvitationExpired
        ? '这次邀请已经过期。重新发送后会刷新邀请时效。'
        : '保留当前待加入关系，并重新提醒该账号完成加入。';
    final activityFeed = _buildTenantMemberActivityFeed(
      history: history,
      auditEvents: auditEvents,
    );
    final queueContextVisible = activeQueueTitle != null;
    final queueSummary = activeQueueTitle == null
        ? null
        : _tenantMemberQueueStatusSummary(
            completionMessage: activeQueueCompletionMessage,
            priorityUsername: queuePriorityMemberUsername,
            nextMemberUsername: queueNextMemberUsername,
            memberIsPriorityTarget: memberIsPriorityTarget,
            memberIsInQueue: true,
          );
    final capabilityLines = <String>[
      if (canManageRoles) '你可以调整此成员的角色。',
      if (canManageStatuses)
        member.status == 'active' ? '你可以停用此成员。' : '你可以更新此成员的可用状态。',
      if (canRemoveMembers)
        member.status == 'invited' ? '你可以撤销这次邀请。' : '你可以将此成员移出租户。',
    ];
    final lockedReasonLines = _tenantMemberLockedReasons(
      member: member,
      activeRole: activeRole,
      activeUserId: activeUserId,
      canManageRoles: canManageRoles,
      canManageStatuses: canManageStatuses,
      canRemoveMembers: canRemoveMembers,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: TelegramPalette.surfaceAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: TelegramPalette.accentDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.username,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${roleMeta.description} · 加入时间：${member.createdAtLabel}',
                        style:
                            const TextStyle(color: TelegramPalette.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(label: '角色', value: roleMeta.label),
                _InfoChip(label: '状态', value: statusMeta.label),
                if (member.status == 'invited')
                  _InfoChip(
                    label: '邀请时效',
                    value: member.isInvitationExpired ? '已过期' : '有效',
                  ),
                if (invitationLifecycle != null)
                  _InfoChip(label: '跟进状态', value: invitationLifecycle.label),
                if (invitationResolution != null)
                  _InfoChip(label: '邀请收口', value: invitationResolution.label),
                _InfoChip(label: '用户 ID', value: member.userId),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TelegramPalette.surfaceAccent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TelegramPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前摘要 · ${statusMeta.label}',
                    style: TextStyle(
                      color: statusMeta.foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusHint,
                    style: const TextStyle(
                      color: TelegramPalette.textMuted,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '当前可执行动作',
                    style: TextStyle(
                      color: TelegramPalette.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...capabilityLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: TelegramPalette.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  if (capabilityLines.isEmpty)
                    const Text(
                      '当前没有可直接执行的操作。',
                      style: TextStyle(
                        color: TelegramPalette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  if (lockedReasonLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TelegramPalette.errorSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TelegramPalette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '当前锁定原因',
                            style: TextStyle(
                              color: TelegramPalette.errorText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...lockedReasonLines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                line,
                                style: const TextStyle(
                                  color: TelegramPalette.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (recentAction != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TelegramPalette.highlight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TelegramPalette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '最近变更 · ${recentAction!.createdAtLabel}',
                            style: const TextStyle(
                              color: TelegramPalette.accentDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            recentAction!.title,
                            style: const TextStyle(
                              color: TelegramPalette.textStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recentAction!.detail,
                            style: const TextStyle(
                              color: TelegramPalette.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (queueContextVisible && queueSummary != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TelegramPalette.surfaceAccent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TelegramPalette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前处理队列 · $activeQueueTitle',
                            style: const TextStyle(
                              color: TelegramPalette.accentDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            queueSummary.detail,
                            style: const TextStyle(
                              color: TelegramPalette.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (activityFeed.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '最近变更记录',
                      style: TextStyle(
                        color: TelegramPalette.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...activityFeed.map(
                      (entry) {
                        final changeMeta = _recentActionMeta(entry.changeType);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TelegramPalette.highlight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TelegramPalette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${entry.title} · ${entry.atLabel}',
                                        style: const TextStyle(
                                          color: TelegramPalette.accentDark,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: entry.source ==
                                                _TenantMemberActivitySource
                                                    .local
                                            ? TelegramPalette.surfaceAccent
                                            : TelegramPalette.highlight,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                            color: TelegramPalette.border),
                                      ),
                                      child: Text(
                                        entry.sourceLabel,
                                        style: TextStyle(
                                          color: entry.source ==
                                                  _TenantMemberActivitySource
                                                      .local
                                              ? TelegramPalette.accentDark
                                              : TelegramPalette.textStrong,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.detail,
                                  style: const TextStyle(
                                    color: TelegramPalette.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                if (entry.changeLabel != null &&
                                    entry.afterValue != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: changeMeta.backgroundColor,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: TelegramPalette.border),
                                    ),
                                    child: Text(
                                      entry.beforeValue == null
                                          ? '${entry.changeLabel}：${entry.afterValue}'
                                          : '${entry.changeLabel}：${entry.beforeValue} → ${entry.afterValue}',
                                      style: TextStyle(
                                        color: changeMeta.foregroundColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '推荐动作',
              style: TextStyle(
                color: TelegramPalette.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (invitationGuidance?.showWaitCard == true) ...[
              _TenantMemberActionInfoCard(
                title: invitationGuidance!.title,
                detail: '${invitationGuidance.detail}如果需要立即生效，再直接激活成员关系。',
              ),
              const SizedBox(height: 10),
            ],
            if (member.status == 'invited' &&
                (canManageStatuses || canRemoveMembers) &&
                prioritizeResend) ...[
              _TenantMemberActionCard(
                title: '重新发送邀请',
                detail: resendDetail,
                emphasized: true,
                onPressed: () => Navigator.of(context).pop(
                  const _TenantMemberActionResult(
                    kind: _TenantMemberActionKind.resendInvite,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (canManageStatuses)
              _TenantMemberActionCard(
                title: statusActionLabel,
                detail: primaryActionDetail,
                emphasized:
                    prioritizeResend ? false : member.status != 'active',
                onPressed: () => Navigator.of(context).pop(
                  _TenantMemberActionResult(
                    kind: _TenantMemberActionKind.updateStatus,
                    value: member.status == 'active' ? 'disabled' : 'active',
                  ),
                ),
              )
            else
              const _TenantMemberActionInfoCard(
                title: '状态操作已锁定',
                detail: '你当前没有权限直接调整此成员的可用状态。',
              ),
            if (member.status == 'invited' &&
                (canManageStatuses || canRemoveMembers) &&
                !prioritizeResend) ...[
              const SizedBox(height: 10),
              _TenantMemberActionCard(
                title: '重新发送邀请',
                detail: resendDetail,
                onPressed: () => Navigator.of(context).pop(
                  const _TenantMemberActionResult(
                    kind: _TenantMemberActionKind.resendInvite,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (canRemoveMembers)
              _TenantMemberActionCard(
                title: removeLabel,
                detail: removeDetail,
                destructive: member.status != 'invited',
                onPressed: () => Navigator.of(context).pop(
                  const _TenantMemberActionResult(
                      kind: _TenantMemberActionKind.remove),
                ),
              )
            else
              const _TenantMemberActionInfoCard(
                title: '危险操作已锁定',
                detail: '你当前不能移除该成员或撤销当前邀请。',
              ),
            const SizedBox(height: 18),
            const Text(
              '调整角色',
              style: TextStyle(
                color: TelegramPalette.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (canManageRoles)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['member', 'admin', 'owner']
                    .where((role) => role != member.role)
                    .map(
                      (role) => OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(
                          _TenantMemberActionResult(
                            kind: _TenantMemberActionKind.updateRole,
                            value: role,
                          ),
                        ),
                        child: Text('改为 ${_roleMeta(role).label}'),
                      ),
                    )
                    .toList(),
              )
            else
              const _TenantMemberActionInfoCard(
                title: '角色调整已锁定',
                detail: '只有具备足够权限的成员才能调整当前角色。',
              ),
          ],
        ),
      ),
    );
  }
}

enum _TenantMemberActivitySource {
  local,
  audit,
}

class _TenantMemberActivityEntry {
  const _TenantMemberActivityEntry({
    required this.title,
    required this.detail,
    required this.atLabel,
    required this.source,
    this.sortAt,
    this.changeType,
    this.changeLabel,
    this.beforeValue,
    this.afterValue,
  });

  final String title;
  final String detail;
  final String atLabel;
  final _TenantMemberActivitySource source;
  final DateTime? sortAt;
  final _TenantMemberRecentActionType? changeType;
  final String? changeLabel;
  final String? beforeValue;
  final String? afterValue;

  String get sourceLabel =>
      source == _TenantMemberActivitySource.local ? '本地' : '审计';
}

List<_TenantMemberActivityEntry> _buildTenantMemberActivityFeed({
  required List<_TenantMemberRecentAction> history,
  required List<TenantMemberAuditEvent> auditEvents,
}) {
  final local = history.map(
    (entry) => _TenantMemberActivityEntry(
      title: entry.title,
      detail: entry.detail,
      atLabel: entry.createdAtLabel,
      source: _TenantMemberActivitySource.local,
      sortAt: entry.createdAt,
      changeType: entry.changeType,
      changeLabel: entry.changeLabel,
      beforeValue: entry.beforeValue,
      afterValue: entry.afterValue,
    ),
  );
  final audit = auditEvents.map(
    (event) => _TenantMemberActivityEntry(
      title: _tenantMemberAuditTitle(event.action),
      detail: event.detail,
      atLabel: _tenantMemberAuditLabel(event.atLabel),
      source: _TenantMemberActivitySource.audit,
      sortAt: DateTime.tryParse(event.atLabel),
      changeType: _tenantMemberAuditChangeType(event.action),
    ),
  );
  final entries = <_TenantMemberActivityEntry>[
    ...local,
    ...audit,
  ];
  entries.sort((left, right) {
    final leftAt = left.sortAt;
    final rightAt = right.sortAt;
    if (leftAt == null && rightAt == null) {
      return 0;
    }
    if (leftAt == null) {
      return 1;
    }
    if (rightAt == null) {
      return -1;
    }
    return rightAt.compareTo(leftAt);
  });
  return entries.take(8).toList();
}

String _tenantMemberAuditTitle(String action) {
  return switch (action) {
    'tenant_member.joined' => '成员关系已记录',
    'tenant_member.invitation_resent' => '邀请重发已记录',
    'tenant_member.role_updated' => '角色变更已记录',
    'tenant_member.status_updated' => '状态变更已记录',
    'tenant_member.removed' => '移除操作已记录',
    _ => action,
  };
}

String _tenantMemberAuditLabel(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw.isEmpty ? '-' : raw;
  }
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

_TenantMemberRecentActionType? _tenantMemberAuditChangeType(String action) {
  return switch (action) {
    'tenant_member.role_updated' => _TenantMemberRecentActionType.role,
    'tenant_member.status_updated' => _TenantMemberRecentActionType.status,
    'tenant_member.invitation_resent' =>
      _TenantMemberRecentActionType.invitation,
    'tenant_member.joined' => _TenantMemberRecentActionType.membership,
    _ => null,
  };
}

class _TenantMemberActionCard extends StatelessWidget {
  const _TenantMemberActionCard({
    required this.title,
    required this.detail,
    required this.onPressed,
    this.destructive = false,
    this.emphasized = false,
  });

  final String title;
  final String detail;
  final VoidCallback onPressed;
  final bool destructive;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = destructive
        ? TelegramPalette.errorSurface
        : emphasized
            ? TelegramPalette.surfaceAccent
            : TelegramPalette.highlight;
    final foregroundColor =
        destructive ? TelegramPalette.errorText : TelegramPalette.textStrong;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TelegramPalette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: TelegramPalette.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: foregroundColor),
          ],
        ),
      ),
    );
  }
}

class _TenantMemberActionInfoCard extends StatelessWidget {
  const _TenantMemberActionInfoCard({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TelegramPalette.highlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TelegramPalette.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: TelegramPalette.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantMemberStatusMeta {
  const _TenantMemberStatusMeta({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _TenantMemberRoleMeta {
  const _TenantMemberRoleMeta({
    required this.label,
    required this.shortLabel,
    required this.description,
  });

  final String label;
  final String shortLabel;
  final String description;
}

List<String> _tenantMemberLockedReasons({
  required TenantMemberSummary member,
  required String activeRole,
  required String activeUserId,
  required bool canManageRoles,
  required bool canManageStatuses,
  required bool canRemoveMembers,
}) {
  return <String>[
    if (!canManageRoles)
      member.userId == activeUserId
          ? '不能调整你自己的角色。'
          : activeRole != 'owner'
              ? '只有所有者可以调整成员角色。'
              : '当前成员角色暂不可调整。',
    if (!canManageStatuses)
      member.userId == activeUserId && member.status == 'active'
          ? '不能停用你自己。'
          : activeRole == 'admin' && member.role != 'member'
              ? '管理员只能调整普通成员的状态。'
              : activeRole == 'member'
                  ? '只有管理员或所有者可以更新成员状态。'
                  : '当前成员状态暂不可调整。',
    if (!canRemoveMembers)
      member.userId == activeUserId
          ? '不能移除你自己。'
          : activeRole == 'admin' && member.role != 'member'
              ? '管理员只能移除普通成员。'
              : activeRole == 'member'
                  ? '只有管理员或所有者可以移除成员。'
                  : '当前成员暂不可移除。',
  ];
}

_TenantMemberStatusMeta _statusMeta(String status) {
  return switch (status) {
    'active' => const _TenantMemberStatusMeta(
        label: '活跃',
        backgroundColor: TelegramPalette.surfaceAccent,
        foregroundColor: TelegramPalette.accentDark,
      ),
    'invited' => const _TenantMemberStatusMeta(
        label: '待加入',
        backgroundColor: TelegramPalette.highlight,
        foregroundColor: TelegramPalette.textStrong,
      ),
    _ => const _TenantMemberStatusMeta(
        label: '已停用',
        backgroundColor: TelegramPalette.errorSurface,
        foregroundColor: TelegramPalette.errorText,
      ),
  };
}

_TenantMemberRoleMeta _roleMeta(String role) {
  return switch (role) {
    'owner' => const _TenantMemberRoleMeta(
        label: '所有者',
        shortLabel: 'Owner',
        description: '所有者，负责高权限设置与关键成员变更',
      ),
    'admin' => const _TenantMemberRoleMeta(
        label: '管理员',
        shortLabel: 'Admin',
        description: '管理员，负责成员维护与日常协作设置',
      ),
    _ => const _TenantMemberRoleMeta(
        label: '成员',
        shortLabel: 'Member',
        description: '成员，参与当前租户的日常协作',
      ),
  };
}

int _roleRank(String role) {
  return switch (role) {
    'owner' => 0,
    'admin' => 1,
    _ => 2,
  };
}

int _tenantMemberStatusRank(TenantMemberSummary member) {
  return switch (member.status) {
    'active' => 0,
    'invited' => member.isInvitationExpired ? 2 : 1,
    _ => 3,
  };
}
