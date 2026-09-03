import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.name,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, email, name, createdAt];
}
