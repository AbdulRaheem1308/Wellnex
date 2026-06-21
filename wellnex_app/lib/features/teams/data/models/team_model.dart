
/// Team model for team challenges feature
class Team {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String captainId;
  final String captainName;
  final List<TeamMember> members;
  final int memberCount;
  final int maxMembers;
  final int totalSteps;
  final int weeklySteps;
  final int rank;
  final bool isPublic;
  final String? inviteCode;
  final DateTime createdAt;

  const Team({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.captainId,
    required this.captainName,
    required this.members,
    required this.memberCount,
    this.maxMembers = 10,
    required this.totalSteps,
    required this.weeklySteps,
    this.rank = 0,
    this.isPublic = true,
    this.inviteCode,
    required this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      captainId: json['captainId'] as String? ??
          (json['captain'] as Map<String, dynamic>?)?['id'] as String? ?? '',
      captainName: json['captainName'] as String? ??
          (json['captain'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      members: (json['members'] as List<dynamic>?)
              ?.map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      memberCount:
          json['memberCount'] as int? ?? (json['members'] as List?)?.length ?? 0,
      maxMembers: json['maxMembers'] as int? ?? 10,
      totalSteps: json['totalSteps'] as int? ?? 0,
      weeklySteps: json['weeklySteps'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      isPublic: json['isPublic'] as bool? ?? true,
      inviteCode: json['inviteCode'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'captainId': captainId,
        'captainName': captainName,
        'memberCount': memberCount,
        'maxMembers': maxMembers,
        'totalSteps': totalSteps,
        'weeklySteps': weeklySteps,
        'rank': rank,
        'isPublic': isPublic,
        'inviteCode': inviteCode,
        'createdAt': createdAt.toIso8601String(),
        'members': members.map((m) => m.toJson()).toList(),
      };

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? captainId,
    String? captainName,
    List<TeamMember>? members,
    int? memberCount,
    int? maxMembers,
    int? totalSteps,
    int? weeklySteps,
    int? rank,
    bool? isPublic,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      captainId: captainId ?? this.captainId,
      captainName: captainName ?? this.captainName,
      members: members ?? this.members,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      totalSteps: totalSteps ?? this.totalSteps,
      weeklySteps: weeklySteps ?? this.weeklySteps,
      rank: rank ?? this.rank,
      isPublic: isPublic ?? this.isPublic,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isFull => memberCount >= maxMembers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() =>
      'Team(id: $id, name: $name, members: $memberCount/$maxMembers)';
}

/// Team member model
class TeamMember {
  final String id;
  final String name;
  final String? avatarUrl;
  final int steps;
  final int weeklySteps;
  final bool isCaptain;
  final DateTime joinedAt;

  const TeamMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.steps,
    required this.weeklySteps,
    this.isCaptain = false,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String? ??
          json['_id'] as String? ??
          json['userId'] as String? ?? '',
      name: json['name'] as String? ??
          (json['user'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String? ??
          (json['user'] as Map<String, dynamic>?)?['avatarUrl'] as String?,
      steps: json['steps'] as int? ?? json['totalSteps'] as int? ?? 0,
      weeklySteps: json['weeklySteps'] as int? ?? 0,
      isCaptain: json['isCaptain'] as bool? ?? json['role'] == 'captain',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'steps': steps,
        'weeklySteps': weeklySteps,
        'isCaptain': isCaptain,
        'joinedAt': joinedAt.toIso8601String(),
      };

  TeamMember copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    int? steps,
    int? weeklySteps,
    bool? isCaptain,
    DateTime? joinedAt,
  }) {
    return TeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      steps: steps ?? this.steps,
      weeklySteps: weeklySteps ?? this.weeklySteps,
      isCaptain: isCaptain ?? this.isCaptain,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMember && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TeamMember(id: $id, name: $name, captain: $isCaptain)';
}

/// Team challenge model
class TeamChallenge {
  final String id;
  final String title;
  final String description;
  final String teamId;
  final int targetSteps;
  final int currentSteps;
  final DateTime startDate;
  final DateTime endDate;

  /// Status values: active | completed | failed
  final String status;
  final int rewardCoins;
  final int rewardXp;

  const TeamChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.teamId,
    required this.targetSteps,
    required this.currentSteps,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.rewardCoins,
    required this.rewardXp,
  });

  factory TeamChallenge.fromJson(Map<String, dynamic> json) {
    // Null-safe date parsing with fallback
    DateTime parseDate(String? raw, DateTime fallback) {
      if (raw == null) return fallback;
      return DateTime.tryParse(raw) ?? fallback;
    }

    final now = DateTime.now();
    return TeamChallenge(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      teamId: json['teamId'] as String? ?? '',
      targetSteps: json['targetSteps'] as int? ?? 0,
      currentSteps: json['currentSteps'] as int? ?? 0,
      startDate: parseDate(json['startDate'] as String?, now),
      endDate: parseDate(json['endDate'] as String?, now.add(const Duration(days: 7))),
      status: json['status'] as String? ?? 'active',
      rewardCoins: json['rewardCoins'] as int? ?? 0,
      rewardXp: json['rewardXp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'teamId': teamId,
        'targetSteps': targetSteps,
        'currentSteps': currentSteps,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'status': status,
        'rewardCoins': rewardCoins,
        'rewardXp': rewardXp,
      };

  TeamChallenge copyWith({
    String? id,
    String? title,
    String? description,
    String? teamId,
    int? targetSteps,
    int? currentSteps,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int? rewardCoins,
    int? rewardXp,
  }) {
    return TeamChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      teamId: teamId ?? this.teamId,
      targetSteps: targetSteps ?? this.targetSteps,
      currentSteps: currentSteps ?? this.currentSteps,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      rewardXp: rewardXp ?? this.rewardXp,
    );
  }

  double get progress => targetSteps > 0 ? currentSteps / targetSteps : 0.0;
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed' || currentSteps >= targetSteps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamChallenge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TeamChallenge(id: $id, title: $title, status: $status, progress: ${(progress * 100).toStringAsFixed(0)}%)';
}
