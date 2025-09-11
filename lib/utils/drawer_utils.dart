import '../widget/Drawer/appDrawer.dart';

class DrawerUtils {
  /// Refresh user roles in the drawer
  /// Call this every time the drawer is opened or when roles need to be updated
  static void refreshDrawerRoles() {
    try {
      print('🔄 DrawerUtils: Refreshing drawer roles...');

      // Check if drawer key is available and drawer is mounted
      if (drawerKey.currentState != null && drawerKey.currentState!.mounted) {
        drawerKey.currentState!.refreshUserRoles();
        print('✅ DrawerUtils: Drawer roles refreshed successfully');
      } else {
        print('⚠️ DrawerUtils: Drawer not available or not mounted');
      }
    } catch (e) {
      print('❌ DrawerUtils: Error refreshing drawer roles: $e');
    }
  }

  /// Check if drawer is available
  static bool isDrawerAvailable() {
    return drawerKey.currentState != null && drawerKey.currentState!.mounted;
  }

  /// Get current drawer state
  static dynamic getDrawerState() {
    return drawerKey.currentState;
  }
}
