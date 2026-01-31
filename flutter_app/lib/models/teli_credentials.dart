/// Stores Teli API credentials and IDs
class TeliCredentials {
  final String? organizationId;
  final String? userId;
  final String? agentId;

  TeliCredentials({
    this.organizationId,
    this.userId,
    this.agentId,
  });

  bool get isComplete =>
      organizationId != null && userId != null && agentId != null;

  factory TeliCredentials.fromJson(Map<String, dynamic> json) {
    return TeliCredentials(
      organizationId: json['organization_id'] as String?,
      userId: json['user_id'] as String?,
      agentId: json['agent_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organization_id': organizationId,
      'user_id': userId,
      'agent_id': agentId,
    };
  }

  TeliCredentials copyWith({
    String? organizationId,
    String? userId,
    String? agentId,
  }) {
    return TeliCredentials(
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      agentId: agentId ?? this.agentId,
    );
  }

  @override
  String toString() {
    return 'TeliCredentials(orgId: $organizationId, userId: $userId, agentId: $agentId)';
  }
}
