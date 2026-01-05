// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamModel _$TeamModelFromJson(Map<String, dynamic> json) => TeamModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      teamCode: json['team_code'] as String?,
      leaderId: json['leader_id'] as String?,
      leaderName: json['leader_name'] as String?,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$TeamModelToJson(TeamModel instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'team_code': instance.teamCode,
      'leader_id': instance.leaderId,
      'leader_name': instance.leaderName,
      'member_count': instance.memberCount,
      'is_active': instance.isActive,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

TeamMember _$TeamMemberFromJson(Map<String, dynamic> json) => TeamMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      teamId: json['team_id'] as String,
      role: json['role'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? false,
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$TeamMemberToJson(TeamMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'team_id': instance.teamId,
      'role': instance.role,
      'display_name': instance.displayName,
      'email': instance.email,
      'avatar_url': instance.avatarUrl,
      'is_active': instance.isActive,
      'is_online': instance.isOnline,
      'joined_at': instance.joinedAt?.toIso8601String(),
    };

CreateTeamRequest _$CreateTeamRequestFromJson(Map<String, dynamic> json) =>
    CreateTeamRequest(
      name: json['name'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$CreateTeamRequestToJson(CreateTeamRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
    };

JoinTeamRequest _$JoinTeamRequestFromJson(Map<String, dynamic> json) =>
    JoinTeamRequest(
      teamId: json['team_id'] as String,
      teamCode: json['team_code'] as String?,
    );

Map<String, dynamic> _$JoinTeamRequestToJson(JoinTeamRequest instance) =>
    <String, dynamic>{
      'team_id': instance.teamId,
      'team_code': instance.teamCode,
    };
