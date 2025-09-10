import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../custom/offline_file_upload.dart' as custom;

class OfflineFileAttachmentWidget extends StatefulWidget {
  final String reportId;
  final String reportType;
  final Function(List<Map<String, dynamic>>)? onFilesAttached;
  final bool showMultiple;

  const OfflineFileAttachmentWidget({
    Key? key,
    required this.reportId,
    required this.reportType,
    this.onFilesAttached,
    this.showMultiple = false,
  }) : super(key: key);

  @override
  State<OfflineFileAttachmentWidget> createState() =>
      _OfflineFileAttachmentWidgetState();
}

class _OfflineFileAttachmentWidgetState
    extends State<OfflineFileAttachmentWidget> {
  List<Map<String, dynamic>> attachedFiles = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAttachedFiles();
  }

  Future<void> _loadAttachedFiles() async {
    final files = await custom
        .OfflineFileUploadService.getOfflineFilesByReportId(widget.reportId);
    setState(() {
      attachedFiles = files;
    });
  }

  Future<void> _attachFile(String fileType) async {
    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> result;

      if (widget.showMultiple) {
        result =
            await custom.OfflineFileUploadService.attachMultipleFilesOffline(
              reportId: widget.reportId,
              reportType: widget.reportType,
              fileType: fileType,
            );
      } else {
        result = await custom.OfflineFileUploadService.attachFileOffline(
          reportId: widget.reportId,
          reportType: widget.reportType,
          fileType: fileType,
        );
      }

      if (result['success']) {
        await _loadAttachedFiles();

        if (widget.onFilesAttached != null) {
          widget.onFilesAttached!(attachedFiles);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error attaching file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deleteFile(String fileId) async {
    try {
      final success = await custom.OfflineFileUploadService.deleteOfflineFile(
        fileId,
      );
      if (success) {
        await _loadAttachedFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File attachment buttons
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach Files',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentButton(
                      icon: Icons.camera_alt,
                      label: 'Screenshot',
                      onTap: () => _attachFile('screenshot'),
                    ),
                    _buildAttachmentButton(
                      icon: Icons.description,
                      label: 'Document',
                      onTap: () => _attachFile('document'),
                    ),
                    _buildAttachmentButton(
                      icon: Icons.videocam,
                      label: 'Video',
                      onTap: () => _attachFile('video'),
                    ),
                    _buildAttachmentButton(
                      icon: Icons.mic,
                      label: 'Audio',
                      onTap: () => _attachFile('audio'),
                    ),
                  ],
                ),
                if (widget.showMultiple) ...[
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentButton(
                        icon: Icons.photo_library,
                        label: 'Multiple Images',
                        onTap: () => _attachFile('screenshots'),
                      ),
                      _buildAttachmentButton(
                        icon: Icons.folder,
                        label: 'Multiple Docs',
                        onTap: () => _attachFile('documents'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Attached files list
        if (attachedFiles.isNotEmpty) ...[
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attached Files (${attachedFiles.length})',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  ...attachedFiles.map((file) => _buildFileItem(file)).toList(),
                ],
              ),
            ),
          ),
        ],

        // Loading indicator
        if (isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onTap,
          icon: Icon(icon, size: 20),
          label: Text(label, style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 8),
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file) {
    final status = file['status'] ?? 'pending';
    final fileName = file['originalName'] ?? 'Unknown file';
    final fileSize = file['fileSize'] ?? 0;
    final category = file['category'] ?? 'unknown';

    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (status) {
      case 'uploaded':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Uploaded';
        break;
      case 'pending':
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      default:
        statusIcon = Icons.error;
        statusColor = Colors.red;
        statusText = 'Error';
    }

    IconData categoryIcon;
    switch (category) {
      case 'screenshot':
        categoryIcon = Icons.camera_alt;
        break;
      case 'document':
        categoryIcon = Icons.description;
        break;
      case 'video':
        categoryIcon = Icons.videocam;
        break;
      case 'audio':
        categoryIcon = Icons.mic;
        break;
      default:
        categoryIcon = Icons.attach_file;
    }

    return ListTile(
      leading: Icon(categoryIcon, color: Colors.blue),
      title: Text(
        fileName,
        style: TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${(fileSize / 1024).toStringAsFixed(1)} KB • $statusText',
        style: TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => _deleteFile(file['id']),
          ),
        ],
      ),
    );
  }
}
