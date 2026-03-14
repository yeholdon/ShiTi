class TenantMemberAuditEvent {
  const TenantMemberAuditEvent({
    required this.id,
    required this.atLabel,
    required this.action,
    required this.targetType,
    required this.detail,
  });

  final String id;
  final String atLabel;
  final String action;
  final String targetType;
  final String detail;
}
