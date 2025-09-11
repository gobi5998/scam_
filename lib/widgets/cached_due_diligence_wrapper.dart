import 'package:flutter/material.dart';
import '../services/due_diligence_cache_service.dart';
import '../screens/Due_diligence/Due_diligence1.dart';

/// Cached wrapper for Due Diligence page
/// Ensures the page loads only once and stays cached
class CachedDueDiligenceWrapper extends StatefulWidget {
  final String? reportId;

  const CachedDueDiligenceWrapper({super.key, this.reportId});

  @override
  State<CachedDueDiligenceWrapper> createState() =>
      _CachedDueDiligenceWrapperState();
}

class _CachedDueDiligenceWrapperState extends State<CachedDueDiligenceWrapper> {
  final DueDiligenceCacheService _cacheService = DueDiligenceCacheService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    try {
      print('📦 CachedDueDiligenceWrapper: Initializing cache...');

      // Update current report ID
      _cacheService.updateCurrentReportId(widget.reportId);

      // Initialize cache (loads data only once)
      await _cacheService.initialize();

      print('📦 CachedDueDiligenceWrapper: Cache initialized successfully');
      print('📦 Cache status: ${_cacheService.getCacheStatus()}');

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('📦 CachedDueDiligenceWrapper: Error initializing cache: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF064FAD)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Due Diligence...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will only load once',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // Return the actual Due Diligence wrapper with cached data
    return DueDiligenceWrapper(reportId: widget.reportId);
  }

  @override
  void dispose() {
    // Don't clear cache on dispose - keep it for next time
    print('📦 CachedDueDiligenceWrapper: Disposed (cache preserved)');
    super.dispose();
  }
}

