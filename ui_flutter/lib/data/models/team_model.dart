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

/// Model for team join requests (worker requesting to join a team)
@JsonSerializable()
class TeamJoinRequest {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'team_id')
  final String teamId;
  final String status; // pending, approved, rejected
  @JsonKey(name: 'requested_at')
  final DateTime? requestedAt;
  @JsonKey(name: 'reviewed_by')
  final String? reviewedBy;
  @JsonKey(name: 'reviewed_at')
  final DateTime? reviewedAt;
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;

  // User details (when joined)
  @JsonKey(name: 'display_name')
  final String? displayName;
  final String? email;
  @JsonKey(name: 'profile_photo_url')
  final String? profilePhotoUrl;
  final String? phone;

  const TeamJoinRequest({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.status,
    this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.displayName,
    this.email,
    this.profilePhotoUrl,
    this.phone,
  });

  /// Custom fromJson that handles nested user object from backend
  factory TeamJoinRequest.fromJson(Map<String, dynamic> json) {
    // Backend returns user details nested in 'user' object
    final user = json['user'] as Map<String, dynamic>?;

    return TeamJoinRequest(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      requestedAt: json['requested_at'] != null
          ? DateTime.tryParse(json['requested_at'].toString())
          : null,
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
      // Extract user details from nested user object, fallback to top-level
      displayName: user?['display_name']?.toString() ?? json['display_name']?.toString(),
      email: user?['email']?.toString() ?? json['email']?.toString(),
      profilePhotoUrl: user?['profile_photo_url']?.toString() ?? json['profile_photo_url']?.toString(),
      phone: user?['phone']?.toString() ?? json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => _$TeamJoinRequestToJson(this);

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
