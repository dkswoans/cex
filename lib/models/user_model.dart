class UserModel {
  const UserModel({
    required this.userId,
    required this.name,
    required this.role,
  });

  final String userId;
  final String name;
  final String role;

  UserModel copyWith({String? userId, String? name, String? role}) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] as String,
      name: map['name'] as String,
      role: map['role'] as String? ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'name': name, 'role': role};
  }
}
