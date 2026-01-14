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
  @JsonKey(name: 'verification_status')
  final String? verificationStatus; // pending, verified, rejected
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
    this.avatarUrl,
    this.phone,
    required this.role,
    this.teamId,
    this.teamName,
    this.isActive = true,
    this.isOnline = false,
    this.verificationStatus,
    this.rejectionReason,
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

  bool get isSuperAdmin => role.toLowerCase() == 'superadmin';
  bool get isAdmin => role.toLowerCase() == 'admin' || isSuperAdmin;
  bool get isTeamLeader {
    final r = role.toLowerCase();
    return r == 'team_leader' || r == 'leader' || r == 'teamleader' || r == 'team-leader';
  }
  bool get isWorker => role.toLowerCase() == 'worker';

  // Verification status helpers
  bool get isPending => verificationStatus == 'pending';
  bool get isVerified => verificationStatus == 'verified';
  bool get isRejected => verificationStatus == 'rejected';
  bool get needsVerification => isTeamLeader || isWorker;

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
    String? verificationStatus,
    String? rejectionReason,
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
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
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

/// Response for registration in the new multi-role system
/// When verification is pending, no tokens are returned
@JsonSerializable()
class RegisterResponse {
  final String? message;
  final UserModel? user;
  @JsonKey(name: 'verification_status')
  final String? verificationStatus; // pending, verified
  @JsonKey(name: 'access_token')
  final String? accessToken;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  const RegisterResponse({
    this.message,
    this.user,
    this.verificationStatus,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      _$RegisterResponseFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterResponseToJson(this);

  /// Returns true if user account is pending verification
  bool get isPending => verificationStatus == 'pending' || accessToken == null;

  /// Returns true if user can login immediately (has tokens)
  bool get canLogin => accessToken != null && accessToken!.isNotEmpty;
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
