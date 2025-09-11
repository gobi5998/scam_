import '../models/user_model.dart';

class RoleUtils {
  // Role names that have access to due diligence
  static const List<String> dueDiligenceRoles = ['client user', 'client admin'];

  // Role names that are regular users (no special access)
  static const List<String> regularUserRoles = ['user'];

  /// Check if user has access to due diligence based on their roles
  static bool canAccessDueDiligence(User? user) {
    if (user == null) return false;

    try {
      final dynamic rolesData = user.getDynamicField('roles');
      if (rolesData != null && rolesData is List) {
        final List<dynamic> roles = rolesData;

        // Check each role
        for (var role in roles) {
          if (role is Map<String, dynamic>) {
            final roleName = role['name']?.toString().toLowerCase();
            if (roleName != null && dueDiligenceRoles.contains(roleName)) {
              return true;
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error checking due diligence access: $e');
    }

    return false;
  }

  /// Check if user has a specific role
  static bool hasRole(User? user, String roleName) {
    if (user == null) return false;

    try {
      final dynamic rolesData = user.getDynamicField('roles');
      if (rolesData != null && rolesData is List) {
        final List<dynamic> roles = rolesData;

        for (var role in roles) {
          if (role is Map<String, dynamic>) {
            final currentRoleName = role['name']?.toString().toLowerCase();
            if (currentRoleName == roleName.toLowerCase()) {
              return true;
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error checking role $roleName: $e');
    }

    return false;
  }

  /// Get all user roles as a list of strings
  static List<String> getUserRoles(User? user) {
    if (user == null) return [];

    try {
      final dynamic rolesData = user.getDynamicField('roles');
      if (rolesData != null && rolesData is List) {
        final List<String> roleNames = [];
        for (var role in rolesData) {
          if (role is Map<String, dynamic>) {
            final roleName = role['name']?.toString();
            if (roleName != null) {
              roleNames.add(roleName);
            }
          }
        }
        return roleNames;
      }
    } catch (e) {
      print('❌ Error getting user roles: $e');
    }

    return [];
  }

  /// Get user roles as a readable string
  static String getUserRolesString(User? user) {
    final roles = getUserRoles(user);
    return roles.isEmpty ? 'No roles found' : roles.join(', ');
  }

  /// Check if user is a regular user (has only 'user' role)
  static bool isRegularUser(User? user) {
    final roles = getUserRoles(user);
    return roles.length == 1 && roles.contains('user');
  }

  /// Check if user is a client user or admin
  static bool isClientUser(User? user) {
    return hasRole(user, 'client user') || hasRole(user, 'client admin');
  }

  /// Get user's primary role (first role in the list)
  static String getPrimaryRole(User? user) {
    final roles = getUserRoles(user);
    return roles.isNotEmpty ? roles.first : 'No role';
  }

  /// Debug method to print all user role information
  static void debugUserRoles(User? user) {
    if (user == null) {
      print('🔍 RoleUtils: No user provided');
      return;
    }

    print('🔍 RoleUtils: Debugging roles for user: ${user.email}');
    print('🔍 RoleUtils: All roles: ${getUserRolesString(user)}');
    print(
      '🔍 RoleUtils: Can access due diligence: ${canAccessDueDiligence(user)}',
    );
    print('🔍 RoleUtils: Is regular user: ${isRegularUser(user)}');
    print('🔍 RoleUtils: Is client user: ${isClientUser(user)}');
    print('🔍 RoleUtils: Primary role: ${getPrimaryRole(user)}');

    // Print raw roles data
    try {
      final dynamic rolesData = user.getDynamicField('roles');
      print('🔍 RoleUtils: Raw roles data: $rolesData');
    } catch (e) {
      print('🔍 RoleUtils: Error getting raw roles data: $e');
    }
  }
}
