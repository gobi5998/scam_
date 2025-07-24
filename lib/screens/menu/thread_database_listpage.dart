import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/scam_report_model.dart';
import '../../models/fraud_report_model.dart';
import '../../models/malware_report_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../scam/scam_report_service.dart';
import '../Fraud/fraud_report_service.dart';
import '../malware/malware_report_service.dart';
import '../../services/malware_reference_service.dart';
import '../dashboard_page.dart';
import 'package:intl/intl.dart';
import 'theard_database.dart';

class ThreadDatabaseListPage extends StatefulWidget {
  final String searchQuery;
  final String? selectedType;
  final String? selectedSeverity;
  final String scamTypeId;

  const ThreadDatabaseListPage({
    Key? key,
    required this.searchQuery,
    this.selectedType,
    this.selectedSeverity,
    required this.scamTypeId,
  }) : super(key: key);

  @override
  State<ThreadDatabaseListPage> createState() => _ThreadDatabaseListPageState();
}

class _ThreadDatabaseListPageState extends State<ThreadDatabaseListPage> {
  final List<Map<String, dynamic>> scamTypes = [];
  Set<int> syncingIndexes = {};

  @override
  void initState() {
    super.initState();
    // Refresh the list when the page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clear duplicates when page loads (same as scam/fraud)
      _clearDuplicateData();
      setState(() {});
    });
  }

  // Method to refresh the list
  void _refreshList() {
    setState(() {});
  }

  // Override didChangeDependencies to refresh when returning from other screens
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh the list when dependencies change (e.g., returning from report creation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Color severityColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
      case 'Critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Utility function to format date and time
  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        } else {
          return '${difference.inMinutes} min ago';
        }
      } else {
        return '${difference.inHours} hours ago';
      }
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }

  // Get the date for a report with proper fallback
  DateTime getReportDate(dynamic report) {
    if (report is MalwareReportModel) {
      return report.date;
    } else if (report.createdAt != null) {
      return report.createdAt!;
    } else {
      // Generate a unique timestamp based on report ID
      final id = report.id ?? '';
      final milliseconds = id.isNotEmpty ? int.tryParse(id) ?? 0 : 0;
      return DateTime.now().add(Duration(milliseconds: milliseconds));
    }
  }

  // Generate unique timestamp for reports
  DateTime generateUniqueTimestamp(String reportId, int index) {
    final baseTime = DateTime.now();
    // Create a more unique offset based on report ID hash and index
    final uniqueOffset =
        (reportId.hashCode + index * 1000) % 60000; // Max 1 minute difference
    return baseTime.subtract(Duration(milliseconds: uniqueOffset));
  }

  // Clear all duplicate data from database
  void _clearDuplicateData() {
    print('=== CLEARING DUPLICATE DATA FROM DATABASE ===');

    final scamBox = Hive.box<ScamReportModel>('scam_reports');
    final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
    final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

    // Track seen content to identify duplicates
    final seenScamContent = <String>{};
    final seenFraudContent = <String>{};
    final seenMalwareContent = <String>{};

    // Remove duplicate scam reports
    for (int i = scamBox.length - 1; i >= 0; i--) {
      final report = scamBox.getAt(i);
      if (report != null) {
        final contentId =
            '${report.description}_${report.createdAt?.millisecondsSinceEpoch}';
        if (seenScamContent.contains(contentId)) {
          print('Removing duplicate scam report: ${report.description}');
          scamBox.deleteAt(i);
        } else {
          seenScamContent.add(contentId);
        }
      }
    }

    // Remove duplicate fraud reports
    for (int i = fraudBox.length - 1; i >= 0; i--) {
      final report = fraudBox.getAt(i);
      if (report != null) {
        final contentId =
            '${report.description}_${report.createdAt?.millisecondsSinceEpoch}';
        if (seenFraudContent.contains(contentId)) {
          print('Removing duplicate fraud report: ${report.description}');
          fraudBox.deleteAt(i);
        } else {
          seenFraudContent.add(contentId);
        }
      }
    }

    // Remove duplicate malware reports
    for (int i = malwareBox.length - 1; i >= 0; i--) {
      final report = malwareBox.getAt(i);
      if (report != null) {
        final contentId =
            '${report.name}_${report.date?.millisecondsSinceEpoch}';
        if (seenMalwareContent.contains(contentId)) {
          print('Removing duplicate malware report: ${report.name}');
          malwareBox.deleteAt(i);
        } else {
          seenMalwareContent.add(contentId);
        }
      }
    }

    print('Duplicate data cleared from database.');
    setState(() {});
  }

  // Debug method to test timestamp generation
  void _debugTimestamps() {
    print('=== DEBUG: Testing Unique Timestamps ===');
    final scamBox = Hive.box<ScamReportModel>('scam_reports');
    final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
    final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

    print('Scam reports: ${scamBox.length}');
    print('Fraud reports: ${fraudBox.length}');
    print('Malware reports: ${malwareBox.length}');

    // Show current timestamps
    for (int i = 0; i < scamBox.length; i++) {
      final report = scamBox.getAt(i);
      if (report != null) {
        print('Scam ${i}: ID=${report.id}, Created=${report.createdAt}');
      }
    }

    for (int i = 0; i < fraudBox.length; i++) {
      final report = fraudBox.getAt(i);
      if (report != null) {
        print('Fraud ${i}: ID=${report.id}, Created=${report.createdAt}');
      }
    }

    for (int i = 0; i < malwareBox.length; i++) {
      final report = malwareBox.getAt(i);
      if (report != null) {
        print('Malware ${i}: ID=${report.id}, Date=${report.date}');
      }
    }
  }

  Future<void> _manualSyncScam(int index, ScamReportModel report) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No internet connection.')));
      return;
    }

    setState(() {
      syncingIndexes.add(index);
    });

    try {
      bool success = await ScamReportService.sendToBackend(report);

      if (success) {
        final box = Hive.box<ScamReportModel>('scam_reports');
        final key = box.keyAt(index);

        final syncedReport = ScamReportModel(
          id: report.id,
          description: report.description,
          alertLevels: report.alertLevels,
          email: report.email,
          phoneNumber: report.phoneNumber,
          website: report.website,
          createdAt: report.createdAt,
          updatedAt: report.updatedAt,
          reportCategoryId: report.reportCategoryId,
          reportTypeId: report.reportTypeId,
          isSynced: true,
        );

        await box.put(key, syncedReport);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scam report synced successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync with server.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error syncing report: $e')));
    } finally {
      setState(() {
        syncingIndexes.remove(index);
      });
    }
  }

  Future<void> _manualSyncFraud(int index, FraudReportModel report) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No internet connection.')));
      return;
    }

    setState(() {
      syncingIndexes.add(index);
    });

    try {
      bool success = await FraudReportService.sendToBackend(report);

      if (success) {
        final box = Hive.box<FraudReportModel>('fraud_reports');
        final key = box.keyAt(index);

        final syncedReport = FraudReportModel(
          id: report.id,
          description: report.description,
          alertLevels: report.alertLevels,
          email: report.email,
          phoneNumber: report.phoneNumber,
          website: report.website,
          createdAt: report.createdAt,
          updatedAt: report.updatedAt,
          reportCategoryId: report.reportCategoryId,
          reportTypeId: report.reportTypeId,
          name: report.name,
          isSynced: true,
        );

        await box.put(key, syncedReport);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fraud report synced successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync with server.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error syncing report: $e')));
    } finally {
      setState(() {
        syncingIndexes.remove(index);
      });
    }
  }

  Future<void> _manualSyncMalware(int index, MalwareReportModel report) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No internet connection.')));
      return;
    }

    setState(() {
      syncingIndexes.add(index);
    });

    try {
      print('🔄 Manual sync for malware report: ${report.name}');

      // Use the new force sync method
      bool success = await MalwareReportService.forceSyncReport(report);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Malware report synced successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to sync with server. Check console for details.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error syncing report: $e')));
    } finally {
      setState(() {
        syncingIndexes.remove(index);
      });
    }
  }

  // Force clear all duplicates with same content
  void _forceClearAllDuplicates() {
    print('=== FORCE CLEARING ALL DUPLICATES ===');

    final scamBox = Hive.box<ScamReportModel>('scam_reports');
    final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
    final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

    // Track seen content to identify duplicates
    final seenScamContent = <String>{};
    final seenFraudContent = <String>{};
    final seenMalwareContent = <String>{};

    print(
      'Before force cleanup - Scam: ${scamBox.length}, Fraud: ${fraudBox.length}, Malware: ${malwareBox.length}',
    );

    // Remove duplicate scam reports (same content regardless of timestamp)
    for (int i = scamBox.length - 1; i >= 0; i--) {
      final report = scamBox.getAt(i);
      if (report != null) {
        final contentId = report.description ?? '';
        if (seenScamContent.contains(contentId)) {
          print(
            '❌ FORCE REMOVING duplicate scam report: ${report.description}',
          );
          scamBox.deleteAt(i);
        } else {
          seenScamContent.add(contentId);
          print('✅ Keeping scam report: ${report.description}');
        }
      }
    }

    // Remove duplicate fraud reports (same content regardless of timestamp)
    for (int i = fraudBox.length - 1; i >= 0; i--) {
      final report = fraudBox.getAt(i);
      if (report != null) {
        final contentId = report.description ?? '';
        if (seenFraudContent.contains(contentId)) {
          print(
            '❌ FORCE REMOVING duplicate fraud report: ${report.description}',
          );
          fraudBox.deleteAt(i);
        } else {
          seenFraudContent.add(contentId);
          print('✅ Keeping fraud report: ${report.description}');
        }
      }
    }

    // Remove duplicate malware reports (same approach as scam/fraud)
    for (int i = malwareBox.length - 1; i >= 0; i--) {
      final report = malwareBox.getAt(i);
      if (report != null) {
        // Use only the name field for malware duplicates, same as scam/fraud use description
        final contentId = report.name ?? '';
        if (seenMalwareContent.contains(contentId)) {
          print('❌ FORCE REMOVING duplicate malware report: ${report.name}');
          malwareBox.deleteAt(i);
        } else {
          seenMalwareContent.add(contentId);
          print('✅ Keeping malware report: ${report.name}');
        }
      }
    }

    print(
      'After force cleanup - Scam: ${scamBox.length}, Fraud: ${fraudBox.length}, Malware: ${malwareBox.length}',
    );
    print('=== END FORCE CLEARING ALL DUPLICATES ===');
  }

  // New method to automatically remove duplicates during loading
  void _autoRemoveDuplicates(
    Box<ScamReportModel> scamBox,
    Box<FraudReportModel> fraudBox,
    Box<MalwareReportModel> malwareBox,
  ) {
    print('=== AUTO DUPLICATE DETECTION ===');

    // Track seen content to identify duplicates
    final seenScamContent = <String>{};
    final seenFraudContent = <String>{};
    final seenMalwareContent = <String>{};

    print(
      'Before cleanup - Scam: ${scamBox.length}, Fraud: ${fraudBox.length}, Malware: ${malwareBox.length}',
    );

    // Remove duplicate scam reports
    for (int i = scamBox.length - 1; i >= 0; i--) {
      final report = scamBox.getAt(i);
      if (report != null) {
        final contentId =
            '${report.description}_${report.createdAt?.millisecondsSinceEpoch}';
        if (seenScamContent.contains(contentId)) {
          print('❌ Removing duplicate scam report: ${report.description}');
          scamBox.deleteAt(i);
        } else {
          seenScamContent.add(contentId);
          print('✅ Keeping scam report: ${report.description}');
        }
      }
    }

    // Remove duplicate fraud reports
    for (int i = fraudBox.length - 1; i >= 0; i--) {
      final report = fraudBox.getAt(i);
      if (report != null) {
        final contentId =
            '${report.description}_${report.createdAt?.millisecondsSinceEpoch}';
        if (seenFraudContent.contains(contentId)) {
          print('❌ Removing duplicate fraud report: ${report.description}');
          fraudBox.deleteAt(i);
        } else {
          seenFraudContent.add(contentId);
          print('✅ Keeping fraud report: ${report.description}');
        }
      }
    }

    // Remove duplicate malware reports (same approach as scam/fraud)
    for (int i = malwareBox.length - 1; i >= 0; i--) {
      final report = malwareBox.getAt(i);
      if (report != null) {
        // Use only the name field for malware duplicates, same as scam/fraud use description
        final contentId = report.name ?? '';
        if (seenMalwareContent.contains(contentId)) {
          print('❌ Removing duplicate malware report: ${report.name}');
          malwareBox.deleteAt(i);
        } else {
          seenMalwareContent.add(contentId);
          print('✅ Keeping malware report: ${report.name}');
        }
      }
    }

    print(
      'After cleanup - Scam: ${scamBox.length}, Fraud: ${fraudBox.length}, Malware: ${malwareBox.length}',
    );
    print('=== END AUTO DUPLICATE DETECTION ===');
  }

  @override
  Widget build(BuildContext context) {
    // Get scam, fraud, and malware reports with real-time data
    final scamBox = Hive.box<ScamReportModel>('scam_reports');
    final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
    final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

    List<ScamReportModel> scamReports = scamBox.values.toList();
    List<FraudReportModel> fraudReports = fraudBox.values.toList();
    List<MalwareReportModel> malwareReports = malwareBox.values.toList();

    // Automatically remove duplicates from database during loading
    _autoRemoveDuplicates(scamBox, fraudBox, malwareBox);

    // Force clear all duplicates with same content
    _forceClearAllDuplicates();

    // Combine reports into a unified list
    List<Map<String, dynamic>> allReports = [];

    // Add scam reports with type indicator and ensure unique timestamps
    for (int i = 0; i < scamReports.length; i++) {
      final report = scamReports[i];
      final cleanedData = {
        'type': 'scam',
        'index': i,
        'report': report,
        'timestamp':
            report.createdAt ?? generateUniqueTimestamp(report.id ?? '', i),
        'uniqueId':
            '${report.id}_scam_${(report.createdAt ?? generateUniqueTimestamp(report.id ?? '', i)).millisecondsSinceEpoch}',
      };
      allReports.add(cleanedData);
    }

    // Add fraud reports with type indicator and ensure unique timestamps
    for (int i = 0; i < fraudReports.length; i++) {
      final report = fraudReports[i];
      final cleanedData = {
        'type': 'fraud',
        'index': i,
        'report': report,
        'timestamp':
            report.createdAt ?? generateUniqueTimestamp(report.id ?? '', i),
        'uniqueId':
            '${report.id}_fraud_${(report.createdAt ?? generateUniqueTimestamp(report.id ?? '', i)).millisecondsSinceEpoch}',
      };
      allReports.add(cleanedData);
    }

    // Add malware reports with type indicator and ensure unique timestamps
    for (int i = 0; i < malwareReports.length; i++) {
      final report = malwareReports[i];
      final cleanedData = {
        'type': 'malware',
        'index': i,
        'report': report,
        'timestamp': report.date ?? generateUniqueTimestamp(report.id ?? '', i),
        'uniqueId':
            '${report.id}_malware_${(report.date ?? generateUniqueTimestamp(report.id ?? '', i)).millisecondsSinceEpoch}',
      };
      allReports.add(cleanedData);
    }

    // Sort by creation date (newest first) - UNIFIED SORTING
    allReports.sort((a, b) {
      DateTime aDate = a['timestamp'];
      DateTime bDate = b['timestamp'];

      // Sort by newest first (descending order)
      return bDate.compareTo(aDate);
    });

    // Remove duplicates based on content and timestamp with aggressive detection
    final seenContent = <String>{};
    final originalCount = allReports.length;
    print('=== AUTO DUPLICATE DETECTION ===');
    print('Original count: $originalCount');

    allReports = allReports.where((item) {
      final report = item['report'];
      final type = item['type'];
      final timestamp = item['timestamp'] as DateTime;

      // Create content-based unique identifier
      String contentId;
      if (report is MalwareReportModel) {
        // Use only the name field for malware duplicates, same as scam/fraud use description
        contentId = '${type}_${report.name}';
      } else {
        contentId =
            '${type}_${report.description}_${timestamp.millisecondsSinceEpoch}';
      }

      print(
        'Checking: $contentId (Type: $type, Content: ${report is MalwareReportModel ? report.name : report.description ?? report.name})',
      );

      if (seenContent.contains(contentId)) {
        print('❌ DUPLICATE FOUND: $contentId');
        return false;
      }
      seenContent.add(contentId);
      print('✅ KEEPING: $contentId');
      return true;
    }).toList();

    final finalCount = allReports.length;
    print('Final count: $finalCount');
    print('Removed ${originalCount - finalCount} duplicates');
    print('=== END DUPLICATE DETECTION ===');

    // Apply filters
    if (widget.searchQuery.isNotEmpty) {
      allReports = allReports.where((item) {
        final report = item['report'];

        // Handle different field names for different report types
        if (report is MalwareReportModel) {
          return (report.name ?? '').toLowerCase().contains(
            widget.searchQuery.toLowerCase(),
          );
        } else {
          return (report.description ?? '').toLowerCase().contains(
            widget.searchQuery.toLowerCase(),
          );
        }
      }).toList();
    }

    if (widget.selectedSeverity != null &&
        widget.selectedSeverity!.isNotEmpty) {
      allReports = allReports.where((item) {
        final report = item['report'];

        // Handle different severity field names for different report types
        if (report is MalwareReportModel) {
          return (report.alertSeverityLevel ?? '') == widget.selectedSeverity;
        } else {
          return (report.alertLevels ?? '') == widget.selectedSeverity;
        }
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          },
        ),
        title: const Text(
          'Thread Database',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.bug_report),
          //   onPressed: () async {
          //     // Run comprehensive debug test
          //     await MalwareReportService.debugSync();
          //     // Show result
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(
          //         content: Text('Debug: Tested endpoints and sync process'),
          //       ),
          //     );
          //   },
          //   tooltip: 'Debug: Test endpoints and force sync',
          // ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'All Reported Records:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ThreadDatabaseFilterPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                  child: const Text('Filter'),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Threads Found: ${allReports.length}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh the list
                setState(() {});
              },
              child: ListView.builder(
                itemCount: allReports.length,
                itemBuilder: (context, i) {
                  final item = allReports[i];
                  final report = item['report'];
                  final reportType = item['type'];
                  final reportIndex = item['index'];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Alert icon with severity level colors
                          CircleAvatar(
                            backgroundColor: severityColor(
                              report is MalwareReportModel
                                  ? (report as MalwareReportModel)
                                            .alertSeverityLevel ??
                                        ''
                                  : report.alertLevels ?? '',
                            ),
                            child: Icon(
                              reportType == 'fraud'
                                  ? Icons.warning
                                  : reportType == 'malware'
                                  ? Icons.warning
                                  : reportType == 'scam'
                                  ? Icons.warning
                                  : Icons.security,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Left side: Type, Description, Name, Time & Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type
                                Text(
                                  'Type: ${reportType.toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Description
                                Text(
                                  report is MalwareReportModel
                                      ? (report as MalwareReportModel).name ??
                                            ''
                                      : report.description ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),

                                // Name (for fraud reports)
                                if (reportType == 'fraud' &&
                                    report.name != null) ...[
                                  Text(
                                    'Name: ${report.name}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                ],

                                // Time & Date
                                Text(
                                  formatDateTime(getReportDate(report)),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right side: Time ago message and sync status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Time ago message
                              Text(
                                formatDateTime(getReportDate(report)),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Sync button or success icon
                              if (report.isSynced == true)
                                const Icon(
                                  Icons.cloud_done,
                                  color: Colors.green,
                                  size: 20,
                                )
                              else if (syncingIndexes.contains(i))
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                )
                              else
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                    maxWidth: 20,
                                    maxHeight: 20,
                                  ),
                                  icon: const Icon(
                                    Icons.sync,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  tooltip: 'Sync now',
                                  onPressed: () {
                                    if (reportType == 'scam') {
                                      _manualSyncScam(reportIndex, report);
                                    } else if (reportType == 'fraud') {
                                      _manualSyncFraud(reportIndex, report);
                                    } else if (reportType == 'malware') {
                                      _manualSyncMalware(reportIndex, report);
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
