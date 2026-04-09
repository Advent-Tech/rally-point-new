// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['display_name'] as String?,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  role: json['role'] as String? ?? 'unknown',
  teamId: json['team_id'] as String?,
  teamName: json['team_name'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  verificationStatus: json['verification_status'] as String?,
  rejectionReason: json['rejection_reason'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'display_name': instance.displayName,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'role': instance.role,
  'team_id': instance.teamId,
  'team_name': instance.teamName,
  'is_active': instance.isActive,
  'verification_status': instance.verificationStatus,
  'rejection_reason': instance.rejectionReason,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
  accessToken: json['access_token'] as String,
  refreshToken: json['refresh_token'] as String?,
  tokenType: json['token_type'] as String? ?? 'Bearer',
  expiresIn: (json['expires_in'] as num?)?.toInt(),
  user: json['user'] == null
      ? null
      : UserModel.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
      'user': instance.user,
    };

TeamModel _$TeamModelFromJson(Map<String, dynamic> json) => TeamModel(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  leaderId: json['leader_id'] as String?,
  leaderName: json['leader_name'] as String?,
  memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$TeamModelToJson(TeamModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'leader_id': instance.leaderId,
  'leader_name': instance.leaderName,
  'member_count': instance.memberCount,
  'is_active': instance.isActive,
  'created_at': instance.createdAt?.toIso8601String(),
};
