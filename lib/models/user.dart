class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'student' | 'teacher' | 'admin'
  final String? phone;
  final int credits;
  final int points;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.phone,
    this.credits = 0,
    this.points = 0,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String?,
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'phone': phone,
        'credits': credits,
        'points': points,
        'created_at': createdAt.toIso8601String(),
      };
}
