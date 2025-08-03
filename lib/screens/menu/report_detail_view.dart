import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/report_model.dart';

class ReportDetailView extends StatefulWidget {
  final Map<String, dynamic> report;
  final ReportModel? typedReport;

  const ReportDetailView({
    Key? key,
    required this.report,
    this.typedReport,
  }) : super(key: key);

  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
        title: Text('Report Details'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Share functionality coming soon')),
              );
            },
            icon: Icon(Icons.share),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            SizedBox(height: 24),
            _buildBasicInfoSection(),
            SizedBox(height: 24),
            _buildContactInfoSection(),
            SizedBox(height: 24),
            _buildTechnicalDetailsSection(),
            SizedBox(height: 24),
            _buildEvidenceSection(),
            SizedBox(height: 24),
            _buildTimelineSection(),
            SizedBox(height: 24),
            _buildMetadataSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final report = widget.report;
    final typedReport = widget.typedReport;

    // Determine report type and severity
    final reportType = _getReportType(report);
    final severity = report['alertLevels'] ?? report['alertSeverityLevel'] ?? 'Unknown';
    final severityColor = _getSeverityColor(severity);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Type and Severity
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  reportType,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Report Title
          Text(
           _getCategoryType(report),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),

          // Description
          if (report['description'] != null && report['description'].toString().isNotEmpty)
            Text(
              report['description'],
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

          SizedBox(height: 16),

          // Status and Priority
          Row(
            children: [
              _buildStatusChip(),
              SizedBox(width: 12),
              if (_getPriority(report) != null)
                _buildPriorityChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final report = widget.report;

    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [

        _buildInfoRow('Category', _getCategoryName(report)),
        _buildInfoRow('Type', _getTypeName(report)),
        _buildInfoRow('Severity Level', report['alertLevels'] ?? report['alertSeverityLevel'] ?? 'Unknown'),
        if (report['status'] != null)
          _buildInfoRow('Status', report['status']),
        if (report['priority'] != null)
          _buildInfoRow('Priority', 'Level ${report['priority']}'),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    final report = widget.report;
    final hasContactInfo = report['email'] != null ||
                          report['phoneNumber'] != null ||
                          report['website'] != null;

    if (!hasContactInfo) return SizedBox.shrink();

    return _buildSection(
      title: 'Contact Information',
      icon: Icons.contact_phone,
      children: [
        if (report['email'] != null)
          _buildInfoRow('Email', report['email'], isLink: true),
        if (report['phoneNumber'] != null)
          _buildInfoRow('Phone Number', report['phoneNumber'], isLink: true),
        if (report['website'] != null)
          _buildInfoRow('Website', report['website'], isLink: true),
      ],
    );
  }

  Widget _buildTechnicalDetailsSection() {
    final report = widget.report;
    final reportType = report['type']?.toString().toLowerCase();

    List<Widget> children = [];

    // Malware-specific details
    if (reportType == 'malware' || report['malwareType'] != null) {
      children.addAll([
        if (report['malwareType'] != null)
          _buildInfoRow('Malware Type', report['malwareType']),
        if (report['infectedDeviceType'] != null)
          _buildInfoRow('Infected Device', report['infectedDeviceType']),
        if (report['operatingSystem'] != null)
          _buildInfoRow('Operating System', report['operatingSystem']),
        if (report['detectionMethod'] != null)
          _buildInfoRow('Detection Method', report['detectionMethod']),
        if (report['fileName'] != null)
          _buildInfoRow('File Name', report['fileName']),
        if (report['systemAffected'] != null)
          _buildInfoRow('System Affected', report['systemAffected']),
      ]);
    }

    // General technical details
    if (report['location'] != null)
      children.add(_buildInfoRow('Location', report['location']));
    if (report['ipAddress'] != null)
      children.add(_buildInfoRow('IP Address', report['ipAddress']));
    if (report['userAgent'] != null)
      children.add(_buildInfoRow('User Agent', report['userAgent']));

    if (children.isEmpty) return SizedBox.shrink();

    return _buildSection(
      title: 'Technical Details',
      icon: Icons.computer,
      children: children,
    );
  }

  Widget _buildEvidenceSection() {
    final report = widget.report;
    final typedReport = widget.typedReport;

    List<String> evidence = [];

    // Screenshots
    if (typedReport?.screenshotPaths.isNotEmpty == true) {
      evidence.addAll(typedReport!.screenshotPaths);
    } else if (report['screenshotPaths'] != null) {
      final screenshots = report['screenshotPaths'];
      if (screenshots is List) {
        evidence.addAll(screenshots.map((e) => e.toString()));
      }
    }

    // Documents
    if (typedReport?.documentPaths.isNotEmpty == true) {
      evidence.addAll(typedReport!.documentPaths);
    } else if (report['documentPaths'] != null) {
      final documents = report['documentPaths'];
      if (documents is List) {
        evidence.addAll(documents.map((e) => e.toString()));
      }
    }

    if (evidence.isEmpty) return SizedBox.shrink();

    return _buildSection(
      title: 'Evidence Files',
      icon: Icons.attach_file,
      children: [
        ...evidence.map((path) => _buildEvidenceItem(path)),
      ],
    );
  }

  Widget _buildTimelineSection() {
    final report = widget.report;
    final typedReport = widget.typedReport;

    final createdAt = report['createdAt'] ?? typedReport?.createdAt;
    final updatedAt = report['updatedAt'] ?? typedReport?.updatedAt;

    if (createdAt == null && updatedAt == null) return SizedBox.shrink();

    return _buildSection(
      title: 'Timeline',
      icon: Icons.schedule,
      children: [
        if (createdAt != null)
          _buildInfoRow('Created', _formatDateTime(createdAt)),
        if (updatedAt != null && updatedAt != createdAt)
          _buildInfoRow('Last Updated', _formatDateTime(updatedAt)),
      ],
    );
  }

  Widget _buildMetadataSection() {
    final report = widget.report;
    final typedReport = widget.typedReport;

    List<Widget> children = [];

    // User information
    if (typedReport?.userName != null)
      children.add(_buildInfoRow('Reported By', typedReport!.userName!));
    if (typedReport?.userEmail != null)
      children.add(_buildInfoRow('User Email', typedReport!.userEmail!));
    if (typedReport?.userId != null)
      children.add(_buildInfoRow('User ID', typedReport!.userId!));

    // Tags
    if (typedReport?.tags.isNotEmpty == true) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tags',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: typedReport!.tags.map((tag) => Chip(
                label: Text(tag),
                backgroundColor: Colors.blue.withOpacity(0.1),
                labelStyle: TextStyle(color: Colors.blue.shade700),
              )).toList(),
            ),
          ],
        ),
      );
    }

    // Additional data
    if (typedReport?.additionalData != null) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                typedReport!.additionalData.toString(),
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      );
    }

    if (children.isEmpty) return SizedBox.shrink();

    return _buildSection(
      title: 'Additional Information',
      icon: Icons.more_horiz,
      children: children,
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, {bool isLink = false}) {
    if (value == null || value.toString().isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: isLink
                ? GestureDetector(
                    onTap: () {
                      // TODO: Implement link handling
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Link: $value')),
                      );
                    },
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  )
                : Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(String path) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: Colors.blue.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              path.split('/').last, // Show filename only
              style: TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Implement file preview/download
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('File: $path')),
              );
            },
            icon: Icon(Icons.download, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _getStatus(widget.report);
    final statusColor = status == 'Completed' ? Colors.green : Colors.orange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 'Completed' ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: statusColor,
          ),
          SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip() {
    final priority = _getPriority(widget.report);
    if (priority == null) return SizedBox.shrink();

    Color priorityColor;
    String priorityText;

    if (priority >= 8) {
      priorityColor = Colors.red;
      priorityText = 'HIGH';
    } else if (priority >= 5) {
      priorityColor = Colors.orange;
      priorityText = 'MEDIUM';
    } else {
      priorityColor = Colors.green;
      priorityText = 'LOW';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priorityText,
        style: TextStyle(
          color: priorityColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Helper methods
  String _getReportType(Map<String, dynamic> report) {
    final type = report['type']?.toString().toLowerCase();
    if (type == 'malware' || report['malwareType'] != null) {
      return 'Malware Report';
    } else if (type == 'fraud') {
      return 'Fraud Report';
    } else if (type == 'scam') {
      return 'Scam Report';
    } else {
      return 'Security Report';
    }
  }

  String _getCategoryType(Map<String, dynamic> report) {
    final categoryObj = report['reportCategoryId'];
    if (categoryObj is Map) {
      return categoryObj['name']?.toString() ?? 'Unknown Category';
    } else if (categoryObj is String) {
      return categoryObj;
    }
    return 'Unknown Category';
  }

  String _getCategoryName(Map<String, dynamic> report) {
    final categoryObj = report['reportCategoryId'];
    if (categoryObj is Map) {
      return categoryObj['name']?.toString() ?? 'Unknown Category';
    } else if (categoryObj is String) {
      return categoryObj;
    }
    return 'Unknown Category';
  }

  String _getTypeName(Map<String, dynamic> report) {
    final typeObj = report['reportTypeId'];
    if (typeObj is Map) {
      return typeObj['name']?.toString() ?? 'Unknown Type';
    } else if (typeObj is String) {
      return typeObj;
    }
    return 'Unknown Type';
  }

  String _getStatus(Map<String, dynamic> report) {
    if (report['isSynced'] == true || report['_id'] != null) {
      return 'Completed';
    }
    return 'Pending';
  }

  int? _getPriority(Map<String, dynamic> report) {
    return report['priority'] is int
        ? report['priority']
        : int.tryParse(report['priority']?.toString() ?? '');
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.purple;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Unknown';

    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        return 'Invalid date';
      }

      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
    } catch (e) {
      return 'Invalid date';
    }
  }
}