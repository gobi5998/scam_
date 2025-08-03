import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  static String _version = '';
  static String _buildNumber = '';
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
      _isInitialized = true;
      print('📱 App Version: $_version (Build: $_buildNumber)');
    } catch (e) {
      print('❌ Error getting app version: $e');
      _version = 'Unknown';
      _buildNumber = '0';
      _isInitialized = true;
    }
  }

  static String get version => _version;
  static String get buildNumber => _buildNumber;
  static String get displayVersion => _version;
  static String get displayVersionWithBuild => '$_version ($_buildNumber)';
  static String get fullVersionInfo =>
      'Version $_version (Build $_buildNumber)';

  static Future<String> getVersionString() async {
    if (!_isInitialized) {
      await initialize();
    }
    return displayVersionWithBuild;
  }

  static Future<Map<String, String>> getVersionInfo() async {
    if (!_isInitialized) {
      await initialize();
    }
    return {
      'version': _version,
      'buildNumber': _buildNumber,
      'displayVersion': displayVersion,
      'displayVersionWithBuild': displayVersionWithBuild,
      'fullVersionInfo': fullVersionInfo,
    };
  }
}
