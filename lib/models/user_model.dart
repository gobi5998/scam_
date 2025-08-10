class User {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? role;
  final String? createdAt;
  final String? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('🔍 Parsing user JSON: $json');
    print('🔍 Available keys: ${json.keys.toList()}');

    final user = User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? json['userName'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? json['firstname'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['lastname'] ?? json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );

    print('🔍 Parsed user:');
    print('  - ID: ${user.id}');
    print('  - Username: ${user.username}');
    print('  - Email: ${user.email}');
    print('  - FirstName: ${user.firstName}');
    print('  - LastName: ${user.lastName}');
    print('  - FullName: ${user.fullName}');

    return user;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return username;
    }
  }
}