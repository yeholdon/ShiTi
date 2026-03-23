class TenantSummary {
  const TenantSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    this.kind = 'organization',
  });

  final String id;
  final String code;
  final String name;
  final String role;
  final String kind;

  bool get isPersonal => kind == 'personal';
  bool get isOrganization => !isPersonal;

  factory TenantSummary.fromJson(Map<String, dynamic> json) {
    return TenantSummary(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '未命名机构').toString(),
      role: (json['role'] ?? 'member').toString(),
      kind: (json['kind'] ?? 'organization').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'name': name,
      'role': role,
      'kind': kind,
    };
  }
}
