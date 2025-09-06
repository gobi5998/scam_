import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/report_model.dart';

class ReportDetailView extends StatefulWidget {
  final Map<String, dynamic> report;
  final ReportModel? typedReport;

  const ReportDetailView({super.key, required this.report, this.typedReport});

  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  final bool _isExpanded = false;
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text('Report Details ', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        elevation: 0,
        // actions: [
        //   IconButton(
        //     onPressed: () {
        //       // Test the specific S3 URL
        //       _testSpecificS3Url();
        //     },
        //     icon: Icon(Icons.bug_report),
        //     tooltip: 'Test S3 Image Loading',
        //   ),
        //   IconButton(
        //     onPressed: () {
        //       // Debug URL extraction
        //       _debugUrlExtraction();
        //     },
        //     icon: Icon(Icons.search),
        //     tooltip: 'Debug URL Extraction',
        //   ),
        //   IconButton(
        //     onPressed: () {
        //       // Test all extracted URLs
        //       _testAllExtractedUrls();
        //     },
        //     icon: Icon(Icons.play_arrow),
        //     tooltip: 'Test All URLs',
        //   ),
        //   IconButton(
        //     onPressed: () {
        //       // TODO: Implement share functionality
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         SnackBar(content: Text('Share functionality coming soon')),
        //       );
        //     },
        //     icon: Icon(Icons.share),
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug indicator to show new version is loaded
            _buildHeaderSection(),
            SizedBox(height: 24),
            // _buildBasicInfoSection(),
            // SizedBox(height: 24),
            _buildContactInfoSection(),
            SizedBox(height: 5),
            _buildTechnicalDetailsSection(),
            SizedBox(height: 24),
            // _buildFinancialDetailsSection(),
            // SizedBox(height: 24),
            // _buildSecurityAnalysisSection(),
            // SizedBox(height: 24),
            // _buildDebugSection(),
            // SizedBox(height: 24),
            _buildMetadataSection(),
            SizedBox(height: 24),
            _buildEvidenceSection(),
            SizedBox(height: 24),
            // _buildTimelineSection(),
            // SizedBox(height: 24),
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
    final severity = _getAlertLevel(report);
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
              // SizedBox(width: 12),
              // Container(
              //   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: Colors.blue.withOpacity(0.1),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Text(
              //     reportType,
              //     style: TextStyle(
              //       color: Colors.blue.shade700,
              //       fontWeight: FontWeight.bold,
              //       fontSize: 12,
              //     ),
              //   ),

              // ),
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
          if (report['description'] != null &&
              report['description'].toString().isNotEmpty)
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
              _buildStatusChip(),
              SizedBox(width: 12),
              if (_getPriority(report) != null) _buildPriorityChip(),
            ],
          ),

          // New: Report ID and Reference
          // SizedBox(height: 16),
          // if (report['_id'] != null || report['reportId'] != null)
          //             Row(
          //     children: [
          //       Icon(Icons.fingerprint, size: 16, color: Colors.grey[600]),
          //       SizedBox(width: 8),
          //       Text(
          //         'ID: ${report['_id'] ?? report['reportId']}',
          //         style: TextStyle(
          //           fontSize: 12,
          //           color: Colors.grey[600],
          //           fontFamily: 'monospace',
          //         ),
          //       ),
          //     ],
          //   ),
        ],
      ),
    );
  }

  // Widget _buildBasicInfoSection() {
  //   final report = widget.report;
  //
  //   return _buildSection(
  //     title: 'Basic Information',
  //     icon: Icons.info_outline,
  //     children: [
  //
  //       _buildInfoRow('Category', _getCategoryName(report)),
  //       _buildInfoRow('Type', _getTypeName(report)),
  //       _buildInfoRow('Severity Level', _getAlertLevel(report)),
  //       if (report['status'] != null)
  //         _buildInfoRow('Status', report['status']),
  //       if (report['priority'] != null)
  //         _buildInfoRow('Priority', 'Level ${report['priority']}'),
  //     ],
  //   );
  // }

  Widget _buildContactInfoSection() {
    final report = widget.report;

    // Check for phone numbers and emails in the correct field names
    final phoneNumbers = report['phoneNumbers'];
    final emails = report['emails'];
    final hasContactInfo =
        emails != null || phoneNumbers != null || report['website'] != null;

    if (!hasContactInfo) return SizedBox.shrink();

    return _buildSection(
      title: 'Contact Information',
      icon: Icons.contact_phone,
      children: [
        if (report['emails'] != null)
          _buildInfoRow('Emails', report['emails'].join(', '), isLink: true),
        if (phoneNumbers != null && phoneNumbers.isNotEmpty)
          _buildInfoRow('Phone Numbers', phoneNumbers.join(', '), isLink: true),
        if (report['website'] != null)
          _buildInfoRow('Website', report['website'], isLink: true),
        if (report['location'] != null &&
            report['location'] is Map<String, dynamic>) ...[
          // if (report['location']['coordinates'] is List && report['location']['coordinates'].length >= 2)
          //   _buildInfoRow('Coordinates', '${report['location']['coordinates'][1]}, ${report['location']['coordinates'][0]}'),
          if (report['location']['address'] != null)
            _buildInfoRow('Address', report['location']['address']),
        ],
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

    // Fraud-specific details
    if (reportType == 'fraud' || report['fraudType'] != null) {
      children.addAll([
        if (report['fraudType'] != null)
          _buildInfoRow('Fraud Type', report['fraudType']),
        if (report['amountInvolved'] != null)
          _buildInfoRow('Amount Involved', report['amountInvolved']),
        if (report['paymentMethod'] != null)
          _buildInfoRow('Payment Method', report['paymentMethod']),
        if (report['transactionId'] != null)
          _buildInfoRow('Transaction ID', report['transactionId']),
        if (report['bankAccount'] != null)
          _buildInfoRow('Bank Account', report['bankAccount']),
      ]);
    }

    // Scam-specific details
    if (reportType == 'scam' || report['scamType'] != null) {
      children.addAll([
        if (report['scamType'] != null)
          _buildInfoRow('Scam Type', report['scamType']),
        if (report['scammerContact'] != null)
          _buildInfoRow('Scammer Contact', report['scammerContact']),
        if (report['scamMethod'] != null)
          _buildInfoRow('Scam Method', report['scamMethod']),
        if (report['targetPlatform'] != null)
          _buildInfoRow('Target Platform', report['targetPlatform']),
      ]);
    }

    // General technical details

    // Network and device details
    if (report['ipAddress'] != null) {
      children.add(_buildInfoRow('IP Address', report['ipAddress']));
    }
    if (report['userAgent'] != null) {
      children.add(_buildInfoRow('User Agent', report['userAgent']));
    }
    if (report['deviceType'] != null) {
      children.add(_buildInfoRow('Device Type', report['deviceType']));
    }
    if (report['browser'] != null) {
      children.add(_buildInfoRow('Browser', report['browser']));
    }
    if (report['platform'] != null) {
      children.add(_buildInfoRow('Platform', report['platform']));
    }

    // Additional technical fields
    if (report['fileSize'] != null) {
      children.add(_buildInfoRow('File Size', report['fileSize']));
    }
    if (report['fileHash'] != null) {
      children.add(_buildInfoRow('File Hash', report['fileHash']));
    }
    if (report['encryptionType'] != null) {
      children.add(_buildInfoRow('Encryption Type', report['encryptionType']));
    }
    if (report['threatLevel'] != null) {
      children.add(_buildInfoRow('Threat Level', report['threatLevel']));
    }

    if (children.isEmpty) return SizedBox.shrink();

    return _buildSection(
      title: 'Technical Details (Enhanced)',
      icon: Icons.computer,
      children: children,
    );
  }

  Widget _buildEvidenceSection() {
    final report = widget.report;
    final typedReport = widget.typedReport;

    // Dynamically extract all S3 URLs from the report data
    List<Map<String, dynamic>> allEvidenceFiles = _extractAllS3UrlsFromReport(
      report,
      typedReport,
    );

    // Categorize files by type
    List<Map<String, dynamic>> screenshots = [];
    List<Map<String, dynamic>> documents = [];
    List<Map<String, dynamic>> voiceMessages = [];
    List<Map<String, dynamic>> videofiles = [];
    List<Map<String, dynamic>> otherFiles = [];

    for (final file in allEvidenceFiles) {
      final filename = file['filename']?.toString().toLowerCase() ?? '';
      final url = file['url']?.toString() ?? '';

      if (url.isEmpty) continue;

      if (_isImageFile(filename)) {
        screenshots.add(file);
      } else if (_isDocumentFile(filename)) {
        documents.add(file);
      } else if (_isAudioFile(filename)) {
        voiceMessages.add(file);
      } else if (_isVideoFile(filename)) {
        videofiles.add(file);
      } else {
        otherFiles.add(file);
      }
    }

    List<Widget> evidenceWidgets = [];

    // Add screenshots section
    if (screenshots.isNotEmpty) {
      evidenceWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Screenshots (${screenshots.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...screenshots.map((file) => _buildEvidenceItem(file)),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    // Add documents section
    if (documents.isNotEmpty) {
      evidenceWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Documents (${documents.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...documents.map((file) => _buildEvidenceItem(file)),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    // Add voice messages section
    if (voiceMessages.isNotEmpty) {
      evidenceWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Voice Messages (${voiceMessages.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...voiceMessages.map((file) => _buildEvidenceItem(file)),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    // Add video files section
    if (videofiles.isNotEmpty) {
      evidenceWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Video Files (${videofiles.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...videofiles.map((file) => _buildEvidenceItem(file)),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    // Add other files section
    if (otherFiles.isNotEmpty) {
      evidenceWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Other Files (${otherFiles.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...otherFiles.map((file) => _buildEvidenceItem(file)),
          ],
        ),
      );
    }

    if (evidenceWidgets.isEmpty) {
      return _buildSection(
        title: 'Evidence Files ',
        icon: Icons.attach_file,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Text(
                      'No Evidence Files Found ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _buildSection(
      title: 'Evidence Files ',
      icon: Icons.attach_file,
      children: evidenceWidgets,
    );
  }

  // New method to dynamically extract all S3 URLs from report data
  List<Map<String, dynamic>> _extractAllS3UrlsFromReport(
    Map<String, dynamic> report,
    ReportModel? typedReport,
  ) {
    List<Map<String, dynamic>> allFiles = [];
    Set<String> seenUrls = {}; // To prevent duplicates

    // Extract from screenshots array
    if (report['screenshots'] != null && report['screenshots'] is List) {
      for (var screenshot in report['screenshots']) {
        if (screenshot is Map<String, dynamic>) {
          final url = screenshot['s3Url'] ?? screenshot['uploadPath'];
          if (url != null && !seenUrls.contains(url)) {
            seenUrls.add(url);
            allFiles.add({
              'url': url,
              'filename':
                  screenshot['originalName'] ??
                  screenshot['fileName'] ??
                  url.split('/').last,
              'type': 'screenshot',
              'source': 'screenshots',
            });
          }
        }
      }
    }

    // Extract from voiceMessages array
    if (report['voiceMessages'] != null && report['voiceMessages'] is List) {
      for (var voiceMessage in report['voiceMessages']) {
        if (voiceMessage is Map<String, dynamic>) {
          final url = voiceMessage['s3Url'] ?? voiceMessage['uploadPath'];
          if (url != null && !seenUrls.contains(url)) {
            seenUrls.add(url);
            allFiles.add({
              'url': url,
              'filename':
                  voiceMessage['originalName'] ??
                  voiceMessage['fileName'] ??
                  url.split('/').last,
              'type': 'voice',
              'source': 'voiceMessages',
            });
          }
        }
      }
    }

    // Extract from documents array
    if (report['documents'] != null && report['documents'] is List) {
      for (var document in report['documents']) {
        if (document is Map<String, dynamic>) {
          final url = document['s3Url'] ?? document['uploadPath'];
          if (url != null && !seenUrls.contains(url)) {
            seenUrls.add(url);
            allFiles.add({
              'url': url,
              'filename':
                  document['originalName'] ??
                  document['fileName'] ??
                  url.split('/').last,
              'type': 'document',
              'source': 'documents',
            });
          }
        }
      }
    }

    // Extract from videofiles array
    if (report['videofiles'] != null && report['videofiles'] is List) {
      for (var videoFile in report['videofiles']) {
        if (videoFile is Map<String, dynamic>) {
          final url = videoFile['s3Url'] ?? videoFile['uploadPath'];
          if (url != null && !seenUrls.contains(url)) {
            seenUrls.add(url);
            allFiles.add({
              'url': url,
              'filename':
                  videoFile['originalName'] ??
                  videoFile['fileName'] ??
                  url.split('/').last,
              'type': 'video',
              'source': 'videofiles',
            });
          }
        }
      }
    }

    // Fallback to typed report if available
    if (typedReport != null) {
      if (typedReport.screenshotPaths.isNotEmpty) {
        for (String path in typedReport.screenshotPaths) {
          if (!seenUrls.contains(path)) {
            seenUrls.add(path);
            allFiles.add({
              'url': path,
              'filename': path.split('/').last,
              'type': 'screenshot',
              'source': 'typedReport.screenshotPaths',
            });
          }
        }
      }

      if (typedReport.documentPaths.isNotEmpty) {
        for (String path in typedReport.documentPaths) {
          if (!seenUrls.contains(path)) {
            seenUrls.add(path);
            allFiles.add({
              'url': path,
              'filename': path.split('/').last,
              'type': 'document',
              'source': 'typedReport.documentPaths',
            });
          }
        }
      }
    }

    print('Extracted ${allFiles.length} unique files from report data');
    for (int i = 0; i < allFiles.length; i++) {
      print(
        '  [$i] ${allFiles[i]['filename']} - ${allFiles[i]['url']} (from ${allFiles[i]['source']})',
      );
    }

    return allFiles;
  }

  // Recursively search through a map for S3 URLs
  void _searchForS3UrlsInMap(
    dynamic data,
    List<Map<String, dynamic>> allFiles,
    Set<String> seenUrls, [
    String path = '',
  ]) {
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final currentPath = path.isEmpty ? key : '$path.$key';

        if (value is String) {
          // Check if this string is an S3 URL
          if (_isValidS3Url(value) && !seenUrls.contains(value)) {
            seenUrls.add(value);
            allFiles.add({
              'url': value,
              'filename': value.split('/').last,
              'type': _getFileTypeFromUrl(value),
              'source': currentPath,
            });
          }
        } else if (value is List) {
          // Search through list items
          for (int i = 0; i < value.length; i++) {
            final item = value[i];
            final itemPath = '$currentPath[$i]';

            if (item is String) {
              if (_isValidS3Url(item) && !seenUrls.contains(item)) {
                seenUrls.add(item);
                allFiles.add({
                  'url': item,
                  'filename': item.split('/').last,
                  'type': _getFileTypeFromUrl(item),
                  'source': itemPath,
                });
              }
            } else if (item is Map) {
              _searchForS3UrlsInMap(item, allFiles, seenUrls, itemPath);
            }
          }
        } else if (value is Map) {
          // Recursively search nested maps
          _searchForS3UrlsInMap(value, allFiles, seenUrls, currentPath);
        }
      }
    }
  }

  // Helper methods for file type detection
  bool _isImageFile(String filename) {
    final extensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.svg',
      '.tiff',
    ];
    return extensions.any((ext) => filename.contains(ext));
  }

  bool _isDocumentFile(String filename) {
    final extensions = [
      '.pdf',
      '.doc',
      '.docx',
      '.txt',
      '.rtf',
      '.odt',
      '.html',
      '.htm',
    ];
    return extensions.any((ext) => filename.contains(ext));
  }

  bool _isAudioFile(String filename) {
    final extensions = [
      '.mp3',
      '.wav',
      '.ogg',
      '.flac',
      '.aac',
      '.m4a',
      '.opus',
      '.amr',
      '.weba',
    ];
    return extensions.any((ext) => filename.contains(ext));
  }

  bool _isVideoFile(String filename) {
    final extensions = [
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.mkv',
      '.m4v',
      '.3gp',
      '.ogv',
    ];
    return extensions.any((ext) => filename.contains(ext));
  }

  String _getFileTypeFromUrl(String url) {
    final filename = url.split('/').last.toLowerCase();
    if (_isImageFile(filename)) return 'screenshot';
    if (_isDocumentFile(filename)) return 'document';
    if (_isAudioFile(filename)) return 'voice';
    if (_isVideoFile(filename)) return 'video';
    return 'other';
  }

  // Widget _buildTimelineSection() {
  //   final report = widget.report;
  //   final typedReport = widget.typedReport;

  //   final createdAt = report['createdAt'] ?? typedReport?.createdAt;
  //   final updatedAt = report['updatedAt'] ?? typedReport?.updatedAt;

  //   if (createdAt == null && updatedAt == null) return SizedBox.shrink();

  //   return _buildSection(
  //     title: 'Timeline',
  //     icon: Icons.schedule,
  //     children: [
  //       if (createdAt != null)
  //         _buildInfoRow('Created', _formatDateTime(createdAt)),
  //       if (updatedAt != null && updatedAt != createdAt)
  //         _buildInfoRow('Last Updated', _formatDateTime(updatedAt)),
  //     ],
  //   );
  // }

  Widget _buildFinancialDetailsSection() {
    final report = widget.report;
    List<Widget> children = [];

    // Financial transaction details
    if (report['amount'] != null) {
      children.add(_buildInfoRow('Amount', report['amount']));
    }
    if (report['currency'] != null) {
      children.add(_buildInfoRow('Currency', report['currency']));
    }
    if (report['paymentMethod'] != null) {
      children.add(_buildInfoRow('Payment Method', report['paymentMethod']));
    }
    if (report['transactionId'] != null) {
      children.add(_buildInfoRow('Transaction ID', report['transactionId']));
    }
    if (report['bankName'] != null) {
      children.add(_buildInfoRow('Bank Name', report['bankName']));
    }
    if (report['accountNumber'] != null) {
      children.add(_buildInfoRow('Account Number', report['accountNumber']));
    }
    if (report['routingNumber'] != null) {
      children.add(_buildInfoRow('Routing Number', report['routingNumber']));
    }
    if (report['cardNumber'] != null) {
      children.add(_buildInfoRow('Card Number', report['cardNumber']));
    }
    if (report['expiryDate'] != null) {
      children.add(_buildInfoRow('Expiry Date', report['expiryDate']));
    }
    if (report['cvv'] != null) {
      children.add(_buildInfoRow('CVV', report['cvv']));
    }
    if (report['merchantName'] != null) {
      children.add(_buildInfoRow('Merchant Name', report['merchantName']));
    }
    if (report['transactionDate'] != null) {
      children.add(
        _buildInfoRow(
          'Transaction Date',
          _formatDateTime(report['transactionDate']),
        ),
      );
    }
    if (report['transactionStatus'] != null) {
      children.add(
        _buildInfoRow('Transaction Status', report['transactionStatus']),
      );
    }
    if (report['refundAmount'] != null) {
      children.add(_buildInfoRow('Refund Amount', report['refundAmount']));
    }
    if (report['chargebackAmount'] != null) {
      children.add(
        _buildInfoRow('Chargeback Amount', report['chargebackAmount']),
      );
    }

    if (children.isEmpty) return SizedBox.shrink();

    return _buildSection(
      title: 'Financial Details',
      icon: Icons.account_balance,
      children: children,
    );
  }

  Widget _buildSecurityAnalysisSection() {
    final report = widget.report;
    List<Widget> children = [];

    // Security analysis details
    if (report['threatLevel'] != null) {
      children.add(_buildInfoRow('Threat Level', report['threatLevel']));
    }
    if (report['riskScore'] != null) {
      children.add(_buildInfoRow('Risk Score', report['riskScore']));
    }
    if (report['vulnerabilityType'] != null) {
      children.add(
        _buildInfoRow('Vulnerability Type', report['vulnerabilityType']),
      );
    }
    if (report['attackVector'] != null) {
      children.add(_buildInfoRow('Attack Vector', report['attackVector']));
    }
    if (report['exploitType'] != null) {
      children.add(_buildInfoRow('Exploit Type', report['exploitType']));
    }
    if (report['cveId'] != null) {
      children.add(_buildInfoRow('CVE ID', report['cveId']));
    }
    if (report['severityScore'] != null) {
      children.add(_buildInfoRow('Severity Score', report['severityScore']));
    }
    if (report['impactLevel'] != null) {
      children.add(_buildInfoRow('Impact Level', report['impactLevel']));
    }
    if (report['detectionMethod'] != null) {
      children.add(
        _buildInfoRow('Detection Method', report['detectionMethod']),
      );
    }
    if (report['mitigationStatus'] != null) {
      children.add(
        _buildInfoRow('Mitigation Status', report['mitigationStatus']),
      );
    }
    if (report['patchStatus'] != null) {
      children.add(_buildInfoRow('Patch Status', report['patchStatus']));
    }
    if (report['falsePositive'] != null) {
      children.add(_buildInfoRow('False Positive', report['falsePositive']));
    }
    if (report['verified'] != null) {
      children.add(_buildInfoRow('Verified', report['verified']));
    }
    if (report['investigationStatus'] != null) {
      children.add(
        _buildInfoRow('Investigation Status', report['investigationStatus']),
      );
    }
    if (report['resolutionTime'] != null) {
      children.add(_buildInfoRow('Resolution Time', report['resolutionTime']));
    }

    if (children.isEmpty) return SizedBox.shrink();

    return _buildSection(
      title: 'Security Analysis',
      icon: Icons.security,
      children: children,
    );
  }

  Widget _buildDebugSection() {
    final report = widget.report;
    List<Widget> children = [];

    // Debug: Show all available fields in the report
    children.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Fields (Debug)',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: report.entries.map((entry) {
                final key = entry.key.toString();
                final value = entry.value;
                String displayValue = value?.toString() ?? 'null';
                if (displayValue.length > 50) {
                  displayValue = '${displayValue.substring(0, 50)}...';
                }
                return Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$key: $displayValue',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    return _buildSection(
      title: 'Debug Information',
      icon: Icons.bug_report,
      children: children,
    );
  }

  Widget _buildMetadataSection() {
    final report = widget.report;
    final typedReport = widget.typedReport;

    List<Widget> children = [];

    // User information
    // if (typedReport?.userName != null)
    //   children.add(_buildInfoRow('Reported By', typedReport!.userName!));
    // if (typedReport?.userEmail != null)
    //   children.add(_buildInfoRow('User Email', typedReport!.userEmail!));
    // if (typedReport?.userId != null)
    //   children.add(_buildInfoRow('User ID', typedReport!.userId!));
    if (report['scammerName'] != null) {
      String scammerName = report['scammerName'].toString();
      String capitalizedName = scammerName
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : '',
          )
          .join(' ');

      children.add(_buildInfoRow('Scammer Name', capitalizedName));
    }

    // Enhanced user details - based on actual JSON structure

    // final keycloackUserId = report['keycloackUserId'];
    // if (keycloackUserId != null)
    //   children.add(_buildInfoRow('User ID', keycloackUserId));

    // // Phone numbers and emails from the actual structure
    // final phoneNumbers = report['phoneNumbers'];
    // if (phoneNumbers != null && phoneNumbers.isNotEmpty) {
    //   children.add(_buildInfoRow('Phone Numbers', phoneNumbers.join(', ')));
    // }

    // final emails = report['emails'];
    // if (emails != null && emails.isNotEmpty) {
    //   children.add(_buildInfoRow('Emails', emails.join(', ')));
    // }

    final mediaHandles = report['mediaHandles'];
    if (mediaHandles != null && mediaHandles.isNotEmpty) {
      children.add(_buildInfoRow('Media Handles', mediaHandles.join(', ')));
    }

    // Report metadata - based on actual JSON structure
    if (report['status'] != null) {
      String status = report['status'].toString();
      String capitalizedStatus =
          status[0].toUpperCase() + status.substring(1).toLowerCase();
      children.add(_buildInfoRow('Status', capitalizedStatus));
    }
    // if (report['reportOutcome'] != null)
    //   children.add(_buildInfoRow('Report Outcome', report['reportOutcome']));
    // if (report['description'] != null)
    //   children.add(_buildInfoRow('Description', report['description']));

    if (report['currency'] != null) {
      children.add(_buildInfoRow('Currency', report['currency']));
    }
    if (report['moneyLost'] != null) {
      children.add(_buildInfoRow('Money Lost', report['moneyLost']));
    }
    if (report['attackName'] != null) {
      children.add(_buildInfoRow('Attack Name', report['attackName']));
    }
    if (report['attackSystem'] != null) {
      children.add(_buildInfoRow('Attack System', report['attackSystem']));
    }

    // System metadata
    if (report['version'] != null) {
      children.add(_buildInfoRow('Version', report['version']));
    }
    if (report['buildNumber'] != null) {
      children.add(_buildInfoRow('Build Number', report['buildNumber']));
    }
    if (report['environment'] != null) {
      children.add(_buildInfoRow('Environment', report['environment']));
    }
    if (report['deployment'] != null) {
      children.add(_buildInfoRow('Deployment', report['deployment']));
    }
    if (report['incidentDate'] != null) {
      children.add(
        _buildInfoRow('Incident Date', _formatDateTime(report['incidentDate'])),
      );
    }
    final createdBy = report['createdBy'];
    if (createdBy != null) children.add(_buildInfoRow('Created By', createdBy));

    final createdAt = report['createdAt'] ?? typedReport?.createdAt;
    final updatedAt = report['updatedAt'] ?? typedReport?.updatedAt;
    if (createdAt == null && updatedAt == null) return SizedBox.shrink();

    children.add(_buildInfoRow('Created At', _formatDateTime(createdAt)));
    // children.add(_buildInfoRow('Last Updated', _formatDateTime(updatedAt)));

    //    if (report['location'] != null) {
    //   final location = report['location'];
    //   if (location is Map<String, dynamic>) {
    //     Handle coordinates
    //     final coordinates = location['coordinates'];
    //     if (coordinates is List && coordinates.length >= 2) {
    //       children.add(_buildInfoRow('Coordinates', '${coordinates[1]}, ${coordinates[0]}'));
    //     }

    //     // Handle address from location object
    //     final address = location['address'];
    //     if (address != null) {
    //       children.add(_buildInfoRow('Address', address));
    //     }
    //   }
    // }

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
              children: typedReport!.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: TextStyle(color: Colors.blue.shade700),
                    ),
                  )
                  .toList(),
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Link: $value')));
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
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(Map<String, dynamic> file) {
    // Extract URL using the helper method
    final String url = _extractUrlFromFile(file);
    final String filename =
        file['filename'] ?? file['originalName'] ?? url.split('/').last;
    final String type = file['type'] ?? 'file';

    // Debug logging for URL
    print('Building evidence item:');
    print('  URL: "$url"');
    print('  Filename: "$filename"');
    print('  Type: "$type"');
    print('  File object: $file');

    // Test with the specific S3 URL if this is an image
    if (filename.toLowerCase().contains('.jpg') ||
        filename.toLowerCase().contains('.jpeg') ||
        filename.toLowerCase().contains('.png') ||
        filename.toLowerCase().contains('.gif')) {
      print('=== TESTING IMAGE LOADING ===');
      _testImageLoading(url);
    }

    // Special handling for video files
    if (type == 'video' || _isVideoFile(filename)) {
      return _buildVideoPlayerItem(file);
    }

    // Determine file type and icon based on filename or extension
    IconData fileIcon = Icons.attach_file;
    Color iconColor = Colors.blue.shade600;

    final fileName = filename.toLowerCase();

    // Screenshots - PNG, JPEG, GIF, WebP, SVG
    if (fileName.contains('.png') ||
        fileName.contains('.jpg') ||
        fileName.contains('.jpeg') ||
        fileName.contains('.gif') ||
        fileName.contains('.webp') ||
        fileName.contains('.svg')) {
      fileIcon = Icons.image;
      iconColor = Colors.green.shade600;
    }
    // Documents - PDF, DOCX, TXT, HTML
    else if (fileName.contains('.pdf')) {
      fileIcon = Icons.picture_as_pdf;
      iconColor = Colors.red.shade600;
    } else if (fileName.contains('.docx') || fileName.contains('.doc')) {
      fileIcon = Icons.description;
      iconColor = Colors.blue.shade600;
    } else if (fileName.contains('.txt')) {
      fileIcon = Icons.text_snippet;
      iconColor = Colors.grey.shade600;
    } else if (fileName.contains('.html') || fileName.contains('.htm')) {
      fileIcon = Icons.code;
      iconColor = Colors.orange.shade600;
    }
    // Voice Messages - opus, flac, amr, m4a, aac, mp3, wav, ogg, weba
    else if (fileName.contains('.opus') ||
        fileName.contains('.flac') ||
        fileName.contains('.amr') ||
        fileName.contains('.m4a') ||
        fileName.contains('.aac') ||
        fileName.contains('.mp3') ||
        fileName.contains('.wav') ||
        fileName.contains('.ogg') ||
        fileName.contains('.weba')) {
      fileIcon = Icons.audiotrack;
      iconColor = Colors.orange.shade600;
    }
    // Other file types
    else if (fileName.contains('.mp4') ||
        fileName.contains('.avi') ||
        fileName.contains('.mov') ||
        fileName.contains('.mkv')) {
      fileIcon = Icons.video_file;
      iconColor = Colors.purple.shade600;
    } else if (fileName.contains('.xls') || fileName.contains('.xlsx')) {
      fileIcon = Icons.table_chart;
      iconColor = Colors.green.shade600;
    } else if (fileName.contains('.ppt') || fileName.contains('.pptx')) {
      fileIcon = Icons.slideshow;
      iconColor = Colors.orange.shade600;
    }

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
          Icon(fileIcon, color: iconColor),
          SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _showFilePreview(context, url, filename, type);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Click to view content',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _showFilePreview(context, url, filename, type);
            },
            icon: Icon(Icons.visibility, size: 20),
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
    if (categoryObj is Map<String, dynamic>) {
      return categoryObj['name']?.toString() ?? 'Unknown Category';
    } else if (categoryObj is String) {
      return categoryObj;
    }
    return 'Unknown Category';
  }

  String _getCategoryName(Map<String, dynamic> report) {
    final categoryObj = report['reportCategoryId'];
    if (categoryObj is Map<String, dynamic>) {
      return categoryObj['name']?.toString() ?? 'Unknown Category';
    } else if (categoryObj is String) {
      return categoryObj;
    }
    return 'Unknown Category';
  }

  String _getTypeName(Map<String, dynamic> report) {
    final typeObj = report['reportTypeId'];
    if (typeObj is Map<String, dynamic>) {
      return typeObj['name']?.toString() ?? 'Unknown Type';
    } else if (typeObj is String) {
      return typeObj;
    }
    return 'Unknown Type';
  }

  String _getAlertLevel(Map<String, dynamic> report) {
    final alertLevelObj = report['alertLevels'] ?? report['alertSeverityLevel'];
    if (alertLevelObj is Map<String, dynamic>) {
      return alertLevelObj['name']?.toString() ?? 'Unknown';
    } else if (alertLevelObj is String) {
      return alertLevelObj;
    }
    return 'Unknown';
  }

  String _getStatus(Map<String, dynamic> report) {
    final isSynced = report['isSynced'];
    final id = report['_id'];

    if (isSynced == true || id != null) {
      return 'Completed';
    }
    return 'Pending';
  }

  int? _getPriority(Map<String, dynamic> report) {
    final priority = report['priority'];
    if (priority is int) {
      return priority;
    } else if (priority is String) {
      return int.tryParse(priority);
    } else if (priority != null) {
      return int.tryParse(priority.toString());
    }
    return null;
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

  String _getFileTypeFromPath(String path) {
    final fileName = path.split('/').last.toLowerCase();

    // Screenshots - PNG, JPEG, GIF, WebP, SVG
    if (fileName.contains('.png') ||
        fileName.contains('.jpg') ||
        fileName.contains('.jpeg') ||
        fileName.contains('.gif') ||
        fileName.contains('.webp') ||
        fileName.contains('.svg')) {
      return 'Screenshot';
    }
    // Documents - PDF, DOCX, TXT, HTML
    else if (fileName.contains('.pdf')) {
      return 'PDF Document';
    } else if (fileName.contains('.docx') || fileName.contains('.doc')) {
      return 'Word Document';
    } else if (fileName.contains('.txt')) {
      return 'Text File';
    } else if (fileName.contains('.html') || fileName.contains('.htm')) {
      return 'HTML Document';
    }
    // Voice Messages - opus, flac, amr, m4a, aac, mp3, wav, ogg, weba
    else if (fileName.contains('.opus') ||
        fileName.contains('.flac') ||
        fileName.contains('.amr') ||
        fileName.contains('.m4a') ||
        fileName.contains('.aac') ||
        fileName.contains('.mp3') ||
        fileName.contains('.wav') ||
        fileName.contains('.ogg') ||
        fileName.contains('.weba')) {
      return 'Voice Message';
    }
    // Other file types
    else if (fileName.contains('.mp4') ||
        fileName.contains('.avi') ||
        fileName.contains('.mov') ||
        fileName.contains('.mkv')) {
      return 'Video File';
    } else if (fileName.contains('.xls') || fileName.contains('.xlsx')) {
      return 'Excel Spreadsheet';
    } else if (fileName.contains('.ppt') || fileName.contains('.pptx')) {
      return 'PowerPoint Presentation';
    } else {
      return 'File';
    }
  }

  Future<String> _fetchFileContent(String url) async {
    try {
      final cleanedUrl = _cleanUrl(url);
      final response = await http.get(Uri.parse(cleanedUrl));

      if (response.statusCode == 200) {
        // Try to decode as UTF-8 first
        try {
          return utf8.decode(response.bodyBytes);
        } catch (e) {
          // If UTF-8 fails, try with latin1
          return latin1.decode(response.bodyBytes);
        }
      } else {
        throw Exception('Failed to load file: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch file content: $e');
    }
  }

  String _extractUrlFromFile(Map<String, dynamic> file) {
    // Try different possible URL fields - return the first valid S3 URL found
    String url = file['url']?.toString() ?? '';
    if (url.isNotEmpty && _isValidS3Url(url)) return url;

    url = file['s3Url']?.toString() ?? '';
    if (url.isNotEmpty && _isValidS3Url(url)) return url;

    url = file['uploadPath']?.toString() ?? '';
    if (url.isNotEmpty && _isValidS3Url(url)) return url;

    url = file['path']?.toString() ?? '';
    if (url.isNotEmpty && _isValidS3Url(url)) return url;

    // If URL is still empty, try to construct it from other fields
    final s3Key = file['s3Key']?.toString() ?? file['key']?.toString() ?? '';
    if (s3Key.isNotEmpty) {
      final constructedUrl =
          'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-scam/$s3Key';
      print('Constructed S3 URL: $constructedUrl');
      return constructedUrl;
    }

    // If we have a filename but no URL, try to construct from filename
    final filename =
        file['filename']?.toString() ?? file['originalName']?.toString() ?? '';
    if (filename.isNotEmpty) {
      // Try to extract any path information from the file object
      final reportId =
          file['reportId']?.toString() ?? file['id']?.toString() ?? '';
      if (reportId.isNotEmpty) {
        final constructedUrl =
            'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-scam/$reportId/$filename';
        print('Constructed URL from filename: $constructedUrl');
        return constructedUrl;
      }
    }

    print('No valid S3 URL found for file: $file');
    return url; // Return empty string if no URL found
  }

  bool _isValidS3Url(String url) {
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://')) &&
        url.contains('amazonaws.com');
  }

  String _cleanUrl(String url) {
    if (url.isEmpty) {
      throw Exception('URL is null or empty');
    }

    // Remove leading/trailing whitespace
    String cleanedUrl = url.trim();

    // Check if URL starts with http or https
    if (!cleanedUrl.startsWith('http://') &&
        !cleanedUrl.startsWith('https://')) {
      // If it doesn't start with http/https, try to add https://
      if (cleanedUrl.startsWith('//')) {
        cleanedUrl = 'https:$cleanedUrl';
      } else if (cleanedUrl.startsWith('/')) {
        // This might be a relative URL, we need the base URL
        cleanedUrl =
            'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com$cleanedUrl';
      } else {
        // Assume it's a relative path and add https://
        cleanedUrl = 'https://$cleanedUrl';
      }
    }

    print('Original URL: "$url"'); // Debug log
    print('Cleaned URL: "$cleanedUrl"'); // Debug log

    return cleanedUrl;
  }

  // Download file from S3 URL and save to local storage
  Future<File?> _downloadFile(String url, String filename) async {
    try {
      print('Downloading file: $filename from $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': '*/*',
        },
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        print('File downloaded successfully: ${file.path}');
        return file;
      } else {
        print('Failed to download file: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  // Initialize audio player for voice messages
  Future<void> _initializeAudioPlayer(String url) async {
    try {
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();

      // Set up audio player listeners
      _audioPlayer!.durationStream.listen((duration) {
        if (duration != null) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer!.positionStream.listen((position) {
        setState(() {
          _position = position;
        });
      });

      _audioPlayer!.playerStateStream.listen((state) {
        setState(() {
          _isPlaying = state.playing;
        });
      });

      // Set audio source
      await _audioPlayer!.setUrl(url);
      print('Audio player initialized for: $url');
    } catch (e) {
      print('Error initializing audio player: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing audio player: $e')),
      );
    }
  }

  // Play/pause audio
  Future<void> _toggleAudio() async {
    try {
      if (_audioPlayer == null) {
        await _initializeAudioPlayer(_getCurrentAudioUrl());
      }

      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play();
      }
    } catch (e) {
      print('Error toggling audio: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
    }
  }

  // Get current audio URL (placeholder - you'll need to track this)
  String _getCurrentAudioUrl() {
    // This is a placeholder - you'll need to track the current audio URL
    return '';
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _testSpecificS3Url() async {
    print('=== TESTING DYNAMIC S3 URL EXTRACTION ===');

    final report = widget.report;
    final typedReport = widget.typedReport;

    // Use the dynamic extraction method
    final allFiles = _extractAllS3UrlsFromReport(report, typedReport);

    if (allFiles.isEmpty) {
      print('No S3 URLs found in report data');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No S3 URLs found in report data'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Test the first S3 URL found
    final firstUrl = allFiles.first['url'];
    print('Testing first dynamic URL: $firstUrl');

    try {
      final result = await _fetchImageBytes(firstUrl);
      if (result != null) {
        print(
          '✅ Dynamic S3 URL loaded successfully! Size: ${result.length} bytes',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dynamic S3 URL loaded successfully! Size: ${result.length} bytes',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Dynamic S3 URL returned null');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dynamic S3 URL returned null'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Dynamic S3 URL failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dynamic S3 URL failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _testAllExtractedUrls() async {
    print('=== TESTING ALL EXTRACTED URLs ===');
    final report = widget.report;
    final typedReport = widget.typedReport;

    // Use the new dynamic extraction method
    final allFiles = _extractAllS3UrlsFromReport(report, typedReport);

    if (allFiles.isEmpty) {
      print('No URLs found to test');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No URLs found to test'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('Found ${allFiles.length} URLs to test:');
    for (int i = 0; i < allFiles.length; i++) {
      print('  [$i] ${allFiles[i]['url']}');
    }

    // Test each URL
    for (int i = 0; i < allFiles.length; i++) {
      final url = allFiles[i]['url'];
      print('\n--- Testing URL $i: $url ---');

      try {
        final result = await _fetchImageBytes(url);
        if (result != null) {
          print('✅ URL $i loaded successfully! Size: ${result.length} bytes');
        } else {
          print('❌ URL $i returned null');
        }
      } catch (e) {
        print('❌ URL $i failed: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tested ${allFiles.length} URLs - check console for results',
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _debugUrlExtraction() {
    print('=== DEBUGGING URL EXTRACTION ===');
    final report = widget.report;
    final typedReport = widget.typedReport;

    print('Report data: $report');
    print('Typed report: $typedReport');

    // Use the new dynamic extraction method
    final allFiles = _extractAllS3UrlsFromReport(report, typedReport);

    print('\n=== EXTRACTED FILES ===');
    if (allFiles.isEmpty) {
      print('❌ No S3 URLs found in the report data');
      print('\n=== SEARCHING FOR ANY URL-LIKE STRINGS ===');
      _searchForAnyUrlsInMap(report, 'report');
    } else {
      print('✅ Found ${allFiles.length} S3 URLs:');
      for (int i = 0; i < allFiles.length; i++) {
        final file = allFiles[i];
        print('  [$i] ${file['filename']}');
        print('      URL: ${file['url']}');
        print('      Type: ${file['type']}');
        print('      Source: ${file['source']}');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Debug info printed to console'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Helper method to search for any URL-like strings (not just S3)
  void _searchForAnyUrlsInMap(dynamic data, String path) {
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final currentPath = path.isEmpty ? key : '$path.$key';

        if (value is String) {
          // Check if this string looks like a URL
          if (value.contains('http') ||
              value.contains('amazonaws.com') ||
              value.contains('.com') ||
              value.contains('.org')) {
            print('  Found URL-like string at $currentPath: $value');
          }
        } else if (value is List) {
          for (int i = 0; i < value.length; i++) {
            final item = value[i];
            final itemPath = '$currentPath[$i]';

            if (item is String) {
              if (item.contains('http') ||
                  item.contains('amazonaws.com') ||
                  item.contains('.com') ||
                  item.contains('.org')) {
                print('  Found URL-like string at $itemPath: $item');
              }
            } else if (item is Map) {
              _searchForAnyUrlsInMap(item, itemPath);
            }
          }
        } else if (value is Map) {
          _searchForAnyUrlsInMap(value, currentPath);
        }
      }
    }
  }

  void _testImageLoading(String url) async {
    try {
      print('Testing image loading for URL: $url');
      final result = await _fetchImageBytes(url);
      if (result != null) {
        print('✅ Image loaded successfully! Size: ${result.length} bytes');
      } else {
        print('❌ Image loading returned null');
      }
    } catch (e) {
      print('❌ Image loading test failed: $e');
    }
  }

  Future<Uint8List?> _fetchImageBytes(String url) async {
    try {
      print('=== IMAGE LOADING DEBUG ===');
      print('Original URL: "$url"');

      if (url.isEmpty) {
        print('❌ URL is empty');
        return null;
      }

      final cleanedUrl = _cleanUrl(url);
      print('Cleaned URL: "$cleanedUrl"');

      final uri = Uri.parse(cleanedUrl);
      print('Parsed URI: $uri');

      // Add more comprehensive headers for S3
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'image/*,*/*;q=0.8,application/octet-stream,*/*;q=0.5',
          'Accept-Encoding': 'gzip, deflate, br',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
          'Pragma': 'no-cache',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response content-type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('✅ Image loaded successfully, size: ${bytes.length} bytes');

        // Validate that we actually got image data
        if (bytes.isNotEmpty) {
          return bytes;
        } else {
          print('❌ Image bytes are empty');
          return null;
        }
      } else if (response.statusCode == 403) {
        print('❌ Access denied (403) - S3 bucket permissions issue');
        throw Exception('Access denied - check S3 bucket permissions');
      } else if (response.statusCode == 404) {
        print('❌ File not found (404)');
        throw Exception('File not found on S3');
      } else {
        print('❌ Failed to load image: HTTP ${response.statusCode}');
        throw Exception('Failed to load image: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching image: $e');
      throw Exception('Failed to fetch image: $e');
    }
  }

  Widget _buildImagePreview(String url, String filename) {
    return Container(
      width: double.infinity,
      height: 400, // Fixed height for better display
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _fetchImageBytes(url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading image...'),
                    SizedBox(height: 8),
                    Text(
                      'URL: $url',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48, color: Colors.red),
                    SizedBox(height: 8),
                    Text('Failed to load image'),
                    SizedBox(height: 8),
                    Text('Error: ${snapshot.error}'),
                    SizedBox(height: 8),
                    Text(
                      'URL: $url',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Trigger rebuild to retry
                        });
                      },
                      child: Text('Retry'),
                    ),
                    SizedBox(height: 16),
                    // Fallback to direct Image.network
                    SizedBox(
                      height: 200,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, size: 32, color: Colors.red),
                                SizedBox(height: 8),
                                Text('Direct load failed'),
                                SizedBox(height: 8),
                                Text(
                                  'Error: $error',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 48, color: Colors.red),
                        SizedBox(height: 8),
                        Text('Failed to display image'),
                        SizedBox(height: 8),
                        Text('Error: $error'),
                      ],
                    ),
                  );
                },
              );
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No image data'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatContent(String content, String filename) {
    final fileName = filename.toLowerCase();

    // Format JSON content
    if (fileName.contains('.json')) {
      try {
        final jsonData = json.decode(content);
        return JsonEncoder.withIndent('  ').convert(jsonData);
      } catch (e) {
        return content; // Return original content if JSON parsing fails
      }
    }

    // Format XML content (basic indentation)
    if (fileName.contains('.xml')) {
      return _formatXml(content);
    }

    // For other text files, return as is
    return content;
  }

  String _formatXml(String xml) {
    // Simple XML formatting with basic indentation
    String formatted = '';
    int indent = 0;
    bool inTag = false;

    for (int i = 0; i < xml.length; i++) {
      String char = xml[i];

      if (char == '<') {
        if (i + 1 < xml.length && xml[i + 1] == '/') {
          // Closing tag
          indent--;
        }
        formatted += '\n${'  ' * indent}$char';
        inTag = true;
      } else if (char == '>') {
        formatted += char;
        if (!inTag) {
          indent++;
        }
        inTag = false;
      } else {
        formatted += char;
      }
    }

    return formatted.trim();
  }

  Widget _buildVoiceMessagePlayer(String url, String filename) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack, color: Colors.orange.shade600, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      filename,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Audio Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () async {
                        try {
                          if (_audioPlayer == null) {
                            await _initializeAudioPlayer(url);
                          }
                          await _toggleAudio();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error playing audio: $e')),
                          );
                        }
                      },
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 48,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Progress Bar
                if (_duration > Duration.zero)
                  Column(
                    children: [
                      Slider(
                        value: _position.inMilliseconds.toDouble(),
                        min: 0,
                        max: _duration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          final position = Duration(
                            milliseconds: value.toInt(),
                          );
                          _audioPlayer?.seek(position);
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_position)),
                            Text(_formatDuration(_duration)),
                          ],
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: 12),
                Text(
                  'Audio Player',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _isPlaying ? 'Playing...' : 'Ready to play',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'S3 Audio URL:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 8),
                SelectableText(
                  url,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilePreview(
    BuildContext context,
    String url,
    String filename,
    String type,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        filename,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(child: _buildFileContent(url, filename, type)),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileContent(String url, String filename, String type) {
    final fileName = filename.toLowerCase();

    // For images, show image preview using both Image.network and our custom loader
    if (fileName.contains('.jpg') ||
        fileName.contains('.jpeg') ||
        fileName.contains('.png') ||
        fileName.contains('.gif') ||
        fileName.contains('.webp') ||
        fileName.contains('.svg')) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List?>(
            future: _fetchImageBytes(url),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading S3 image...'),
                      SizedBox(height: 8),
                      Text(
                        'URL: $url',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red),
                      SizedBox(height: 8),
                      Text('Failed to load S3 image'),
                      SizedBox(height: 8),
                      Text('Error: ${snapshot.error}'),
                      SizedBox(height: 8),
                      Text(
                        'URL: $url',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            // Trigger rebuild to retry
                          });
                        },
                        child: Text('Retry'),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Trying fallback method...',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                      SizedBox(height: 8),
                      // Fallback to direct Image.network
                      SizedBox(
                        height: 200,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 32,
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: 8),
                                  Text('Fallback also failed'),
                                  SizedBox(height: 8),
                                  Text(
                                    'Error: $error',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.data != null) {
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red),
                          SizedBox(height: 8),
                          Text('Failed to display image'),
                          SizedBox(height: 8),
                          Text('Error: $error'),
                        ],
                      ),
                    );
                  },
                );
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text('No image data'),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    // For PDF files, show in-app PDF viewer
    if (fileName.contains('.pdf')) {
      return FutureBuilder<File?>(
        future: _downloadFile(url, filename),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Downloading PDF...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Failed to download PDF'),
                  SizedBox(height: 8),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final file = snapshot.data;
          if (file != null && file.existsSync()) {
            return SizedBox(
              width: double.infinity,
              height: 600,
              child: PDFView(
                filePath: file.path,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onError: (error) {
                  print('PDF Error: $error');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('PDF Error: $error')));
                },
                onPageError: (page, error) {
                  print('PDF Page Error: $error');
                },
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Failed to load PDF'),
                ],
              ),
            );
          }
        },
      );
    }

    // For DOCX files, show download and open option
    if (fileName.contains('.docx') || fileName.contains('.doc')) {
      return FutureBuilder<File?>(
        future: _downloadFile(url, filename),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Downloading document...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Failed to download document'),
                  SizedBox(height: 8),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final file = snapshot.data;
          if (file != null && file.existsSync()) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, size: 64, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'Document Ready',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(filename),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final result = await OpenFilex.open(file.path);
                        if (result.type != ResultType.done) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error opening file: ${result.message}',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error opening file: $e')),
                        );
                      }
                    },
                    icon: Icon(Icons.open_in_new),
                    label: Text('Open Document'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Failed to load document'),
                ],
              ),
            );
          }
        },
      );
    }

    // For text-based files, fetch and display content
    if (fileName.contains('.txt') ||
        fileName.contains('.html') ||
        fileName.contains('.htm') ||
        fileName.contains('.json') ||
        fileName.contains('.xml') ||
        fileName.contains('.csv') ||
        fileName.contains('.log') ||
        fileName.contains('.md')) {
      return FutureBuilder<String>(
        future: _fetchFileContent(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading file content...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Failed to load content'),
                  SizedBox(height: 8),
                  Text('Error: ${snapshot.error}'),
                  SizedBox(height: 8),
                  Text(
                    'URL: $url',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final content = snapshot.data ?? 'No content available';
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Name: $filename'),
                      Text('Type: ${_getFileTypeFromPath(filename)}'),
                      Text('Category: ${type.toUpperCase()}'),
                      Text('Content Length: ${content.length} characters'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    _formatContent(content, filename),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // For voice messages, show audio player
    if (fileName.contains('.opus') ||
        fileName.contains('.flac') ||
        fileName.contains('.amr') ||
        fileName.contains('.m4a') ||
        fileName.contains('.aac') ||
        fileName.contains('.mp3') ||
        fileName.contains('.wav') ||
        fileName.contains('.ogg') ||
        fileName.contains('.weba')) {
      return _buildVoiceMessagePlayer(url, filename);
    }

    // For other files, show file info and URL
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Name: $filename'),
                Text('Type: ${_getFileTypeFromPath(filename)}'),
                Text('Category: ${type.toUpperCase()}'),
                SizedBox(height: 8),
                Text(
                  'S3 URL:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    url,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.blue[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Preview not available for this file type.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Click "Open in Browser" to view the file content.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerItem(Map<String, dynamic> file) {
    final String url = _extractUrlFromFile(file);
    final String filename =
        file['filename'] ?? file['originalName'] ?? url.split('/').last;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_file, color: Colors.purple.shade600),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  filename,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.play_circle_filled,
                  color: Colors.purple.shade600,
                ),
                onPressed: () {
                  _showVideoPlayer(context, url, filename);
                },
                tooltip: 'Play Video',
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Video File',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, String url, String filename) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return VideoPlayerDialog(videoUrl: url, title: filename);
      },
    );
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerDialog({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Initialize video player controller
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      // Wait for the controller to initialize
      await _videoPlayerController!.initialize();

      // Create Chewie controller for better UI
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
      print('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Video Player
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Loading video...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.white, size: 48),
                          SizedBox(height: 16),
                          Text(
                            'Error',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _initializeVideoPlayer();
                            },
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : Center(
                      child: Text(
                        'Video player not available',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
