class TenantMemberSummary {
  const TenantMemberSummary({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    required this.status,
    required this.createdAtLabel,
    this.updatedAtIso,
    this.invitationExpiresAtIso,
  });

  final String id;
  final String userId;
  final String username;
  final String role;
  final String status;
  final String createdAtLabel;
  final String? updatedAtIso;
  final String? invitationExpiresAtIso;

  bool get isInvitationExpired {
    if (status != 'invited' || invitationExpiresAtIso == null) {
      return false;
    }
    final parsed = DateTime.tryParse(invitationExpiresAtIso!);
    if (parsed == null) {
      return false;
    }
    return parsed.isBefore(DateTime.now());
  }

  TenantMemberSummary copyWith({
    String? id,
    String? userId,
    String? username,
    String? role,
    String? status,
    String? createdAtLabel,
    String? updatedAtIso,
    String? invitationExpiresAtIso,
  }) {
    return TenantMemberSummary(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAtLabel: createdAtLabel ?? this.createdAtLabel,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      invitationExpiresAtIso: invitationExpiresAtIso ?? this.invitationExpiresAtIso,
    );
  }
}
