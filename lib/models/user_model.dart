class UserModel {
  final String username;
  final String token;
  final String role;

  UserModel({
    required this.username,
    required this.token,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'] as String,
      token: json['token'] as String,
      role: json['role'] as String,
    );
  }

  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';
}
