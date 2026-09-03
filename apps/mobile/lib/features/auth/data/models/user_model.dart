import '../../domain/entities/user.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  factory UserModel.fromEntity(User entity) => UserModel(
        id: entity.id,
        email: entity.email,
        name: entity.name,
        createdAt: entity.createdAt,
      );

  final String id;
  final String email;
  final String name;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  User toEntity() => User(
        id: id,
        email: email,
        name: name,
        createdAt: createdAt,
      );
}
