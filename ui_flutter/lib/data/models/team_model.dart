import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';

part 'team_model.g.dart';

@JsonSerializable()
class TeamModel {
  final String id;
  final String name;
  final String? description;
  @JsonKey(name: 'team_code')
  final String? teamCode;
  @JsonKey(name: 'leader_id')
  final String? leaderId;
  @JsonKey(name: 'leader_name')
  final String? leaderName;
  @JsonKey(name: 'member_count')
  final int memberCount;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const TeamModel({
    required this.id,
    required this.name,
    this.description,
    this.teamCode,
    this.leaderId,
    this.leaderName,
    this.memberCount = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) => _$TeamModelFromJson(json);
  Map<String, dynamic> toJson() => _$TeamModelToJson(this);
}

@JsonSerializable()
class TeamMember {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'team_id')
  final String teamId;
  final String role;
  @JsonKey(name: 'display_name')
  final String? displayName;
  final String? email;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'is_online')
  final bool isOnline;
  @JsonKey(name: 'joined_at')
  final DateTime? joinedAt;

  const TeamMember({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.role,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.isActive = true,
    this.isOnline = false,
    this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => _$TeamMemberFromJson(json);
  Map<String, dynamic> toJson() => _$TeamMemberToJson(this);

  /// Factory to parse User objects from backend (returned by /teams/:id/workers)
  factory TeamMember.fromUserJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return TeamMember(
      id: id,  // Use user ID as membership ID since backend doesn't return separate membership
      userId: id,
      teamId: json['team_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'worker',
      displayName: json['display_name']?.toString(),
      email: json['email']?.toString(),
      avatarUrl: json['profile_photo_url']?.toString(),
      isActive: true,
      isOnline: json['is_online'] == true,
      joinedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  bool get isLeader => role == 'team_leader' || role == 'admin';
}

@JsonSerializable()
class CreateTeamRequest {
  final String name;
  final String? description;

  const CreateTeamRequest({
    required this.name,
    this.description,
  });

  factory CreateTeamRequest.fromJson(Map<String, dynamic> json) => _$CreateTeamRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateTeamRequestToJson(this);
}

@JsonSerializable()
class JoinTeamRequest {
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'team_code')
  final String? teamCode;

  const JoinTeamRequest({
    required this.teamId,
    this.teamCode,
  });

  factory JoinTeamRequest.fromJson(Map<String, dynamic> json) => _$JoinTeamRequestFromJson(json);
  Map<String, dynamic> toJson() => _$JoinTeamRequestToJson(this);
}
