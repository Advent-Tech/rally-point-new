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
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final String? phone;
  final String role;
  @JsonKey(name: 'team_id')
  final String? teamId;
  @JsonKey(name: 'team_name')
  final String? teamName;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'is_online')
  final bool isOnline;
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
    this.avatarUrl,
    this.phone,
    required this.role,
    this.teamId,
    this.teamName,
    this.isActive = true,
    this.isOnline = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return displayName ?? email;
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isTeamLeader {
    final r = role.toLowerCase();
    return r == 'team_leader' || r == 'leader' || r == 'teamleader' || r == 'team-leader';
  }
  bool get isWorker => role.toLowerCase() == 'worker';

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? phone,
    String? role,
    String? teamId,
    String? teamName,
    bool? isActive,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  final String? phone;
  @JsonKey(name: 'team_id')
  final String? teamId;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.phone,
    this.teamId,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}
