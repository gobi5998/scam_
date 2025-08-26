import '../models/file_model.dart';

class FileHandlingService {
  /// Convert backend file objects to FileModel objects
  static List<FileModel> parseBackendFiles(dynamic files) {
    if (files == null) return [];
    
    if (files is List) {
      return files.map((file) {
        if (file is Map<String, dynamic>) {
          return FileModel.fromJson(file);
        } else if (file is String) {
          return FileModel.fromString(file);
        } else {
          return FileModel.fromString(file.toString());
        }
      }).toList();
    }
    
    return [];
  }

  /// Convert local file paths to FileModel objects for offline storage
  static List<FileModel> convertLocalPathsToModels(List<String> filePaths) {
    return filePaths.map((path) => FileModel.fromString(path)).toList();
  }

  /// Extract file URLs from FileModel objects for API calls
  static List<String> extractFileUrls(List<FileModel> files) {
    return files.map((file) => file.displayUrl).where((url) => url.isNotEmpty).toList();
  }

  /// Check if files need to be uploaded (are local paths)
  static bool hasUnuploadedFiles(List<FileModel> files) {
    return files.any((file) => file.isLocalPath);
  }

  /// Get files that need to be uploaded
  static List<FileModel> getUnuploadedFiles(List<FileModel> files) {
    return files.where((file) => file.isLocalPath).toList();
  }

  /// Get files that are already uploaded
  static List<FileModel> getUploadedFiles(List<FileModel> files) {
    return files.where((file) => file.isComplete).toList();
  }

  /// Merge backend files with local files, prioritizing backend data
  static List<FileModel> mergeFiles(List<FileModel> backendFiles, List<FileModel> localFiles) {
    final Map<String, FileModel> merged = {};
    
    // Add local files first
    for (final file in localFiles) {
      final key = file.uploadPath ?? file.fileName ?? '';
      if (key.isNotEmpty) {
        merged[key] = file;
      }
    }
    
    // Override with backend files (they have more complete information)
    for (final file in backendFiles) {
      final key = file.uploadPath ?? file.fileName ?? '';
      if (key.isNotEmpty) {
        merged[key] = file;
      }
    }
    
    return merged.values.toList();
  }

  /// Convert FileModel objects to the format expected by the backend
  static List<Map<String, dynamic>> toBackendFormat(List<FileModel> files) {
    return files.map((file) => file.toJson()).toList();
  }

  /// Get display information for files
  static List<Map<String, String>> getFileDisplayInfo(List<FileModel> files) {
    return files.map((file) => {
      'name': file.displayName,
      'url': file.displayUrl,
      'type': file.contentType ?? 'unknown',
      'size': file.size?.toString() ?? '0',
    }).toList();
  }
}
