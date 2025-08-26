class User {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? role;
  final String? imageUrl; // Profile image URL
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? additionalData; // Store all additional dynamic data

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.role,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('🔍 Available keys: ${json.keys.toList()}');

    // Convert id to string if it's numeric
    final dynamic idValue = json['id'] ?? json['_id'] ?? json['sub'];
    final String id = idValue?.toString() ?? '';

    // Store all original data for dynamic access
    final Map<String, dynamic> additionalData = Map<String, dynamic>.from(json);

    final user = User(
      id: id,
      username:
          json['username'] ??
          json['userName'] ??
          json['name'] ??
          json['preferred_username'] ??
          '',
      email: json['email'] ?? '',
      firstName:
          json['firstName'] ?? 
          json['firstname'] ?? 
          json['first_name'] ?? 
          json['given_name'] ?? // JWT token field
          '',
      lastName: json['lastName'] ?? 
          json['lastname'] ?? 
          json['last_name'] ?? 
          json['family_name'] ?? // JWT token field
          '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      imageUrl: (() {
        final imageUrl = json['imageUrl'] ?? 
            json['image_url'] ?? 
            json['profileImage'] ?? 
            json['profile_image'] ?? 
            json['avatar'] ?? 
            json['avatarUrl'] ?? 
            json['avatar_url'] ?? 
            '';
        
        print('🖼️ User.fromJson - Found imageUrl: $imageUrl');
        print('🖼️ User.fromJson - All JSON keys: ${json.keys.toList()}');
        print('🖼️ User.fromJson - imageUrl field: ${json['imageUrl']}');
        print('🖼️ User.fromJson - image_url field: ${json['image_url']}');
        print('🖼️ User.fromJson - profileImage field: ${json['profileImage']}');
        
        return imageUrl;
      })(),
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      additionalData: additionalData,
    );

    return user;
  }

  Map<String, dynamic> toJson() {
    // If we have additional data, return it as is (preserves original format)
    if (additionalData != null) {
      return Map<String, dynamic>.from(additionalData!);
    }
    
    // Fallback to basic format
    return {
      'sub': id,
      'name': username,
      'preferred_username': username,
      'given_name': firstName,
      'family_name': lastName,
      'email': email,
      'imageUrl': imageUrl,
      'email_verified': true,
      'roles': [
        {
          'id': '584d888b-c316-4b83-a7e9-8dd037aa1980',
          'name': 'user',
          'description': '',
          'composite': false,
          'clientRole': false,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951'
        }
      ],
      'group': null,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null && firstName!.isNotEmpty && lastName!.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName != null && firstName!.isNotEmpty) {
      return firstName!;
    } else if (lastName != null && lastName!.isNotEmpty) {
      return lastName!;
    } else if (username.isNotEmpty) {
      return username;
    } else {
      return email;
    }
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    String? imageUrl,
    String? createdAt,
    String? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  // Method to get any dynamic field from the original data
  dynamic getDynamicField(String fieldName) {
    return additionalData?[fieldName];
  }

  // Method to get all dynamic data
  Map<String, dynamic>? getAllDynamicData() {
    return additionalData;
  }

  // Method to check if a dynamic field exists
  bool hasDynamicField(String fieldName) {
    return additionalData?.containsKey(fieldName) ?? false;
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
