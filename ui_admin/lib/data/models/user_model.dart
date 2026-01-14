import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String email;
  @JsonKey(name: 'display_name')
  final String? displayName;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  @JsonKey(defaultValue: 'unknown')
  final String role;
  @JsonKey(name: 'team_id')
  final String? teamId;
  @JsonKey(name: 'team_name')
  final String? teamName;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'verification_status')
  final String? verificationStatus;
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    required this.role,
    this.teamId,
    this.teamName,
    this.isActive = true,
    this.verificationStatus,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  String get fullName {
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return displayName ?? email;
  }

  bool get isSuperAdmin => role.toLowerCase() == 'superadmin';
  bool get isAdmin => role.toLowerCase() == 'admin' || isSuperAdmin;
  bool get isTeamLeader => role.toLowerCase() == 'team_leader';
  bool get isWorker => role.toLowerCase() == 'worker';
  bool get isPending => verificationStatus == 'pending';
  bool get isVerified => verificationStatus == 'verified';
  bool get isRejected => verificationStatus == 'rejected';
}

@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'expires_in')
  final int? expiresIn;
  final UserModel? user;

  const AuthResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class TeamModel {
  final String id;
  final String name;
  final String? description;
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

  const TeamModel({
    required this.id,
    required this.name,
    this.description,
    this.leaderId,
    this.leaderName,
    this.memberCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) => _$TeamModelFromJson(json);
  Map<String, dynamic> toJson() => _$TeamModelToJson(this);
}
