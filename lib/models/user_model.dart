class User {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? role;
  final String? profileImageUrl;
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
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('🔍 Available keys: ${json.keys.toList()}');

    final user = User(
      id: json['id'] ?? json['_id'] ?? json['sub'] ?? '',
      username:
          json['username'] ??
          json['userName'] ??
          json['name'] ??
          json['preferred_username'] ??
          '',
      email: json['email'] ?? '',
      firstName:
          json['firstName'] ?? json['firstname'] ?? json['first_name'] ?? '',
      lastName: json['lastName'] ?? json['lastname'] ?? json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );

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
      'profileImageUrl': profileImageUrl,
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








// class User {
//   final String id;
//   final String username;
//   final String email;

//   User({
//     required this.id,
//     required this.username,
//     required this.email,

//   });

//   factory User.fromJson(Map<String, dynamic> json) {
//     return User(
//       id: json['id']?? '',
//       username: json['username']?? '',
//       email: json['email']?? '',

//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'username': username,
//       'email': email,


//     };
//   }
// }
