# File Model Integration for Security Alert App

## Overview
This update introduces a new `FileModel` class that handles both online (backend) and offline (local) file formats, ensuring seamless synchronization between online and offline modes.

## Key Changes

### 1. New FileModel Class
The `FileModel` class (`lib/models/file_model.dart`) handles:
- **Backend file objects**: Complete file information from API responses
- **Local file paths**: Simple file paths for offline storage
- **Automatic conversion**: Between different formats as needed

### 2. Updated Report Models
All report models now use `FileModel` instead of simple strings:
- `FraudReportModel`
- `ScamReportModel` 
- `MalwareReportModel`

### 3. FileHandlingService
A utility service (`lib/services/file_handling_service.dart`) provides:
- File parsing from backend responses
- Conversion between formats
- File synchronization helpers

## Usage Examples

### Creating a Report with Files

```dart
// For offline storage (local file paths)
final report = FraudReportModel(
  id: 'local_123',
  description: 'Fraud report',
  screenshots: [
    FileModel.fromString('/path/to/local/image.jpg'),
    FileModel.fromString('/path/to/local/document.pdf'),
  ],
  isSynced: false,
);

// For online storage (backend file objects)
final onlineReport = FraudReportModel(
  id: 'server_456',
  description: 'Fraud report',
  screenshots: [
    FileModel.fromJson({
      'uploadPath': 'https://s3.amazonaws.com/file1.jpg',
      's3Url': 'https://s3.amazonaws.com/file1.jpg',
      'fileId': 'file123',
      'originalName': 'screenshot.jpg',
      'size': 1024,
      'contentType': 'image/jpeg',
    }),
  ],
  isSynced: true,
);
```

### Parsing Backend Responses

```dart
// The models automatically handle both formats
final report = FraudReportModel.fromJson({
  'id': '123',
  'description': 'Fraud report',
  'screenshots': [
    {
      'uploadPath': 'https://s3.amazonaws.com/file1.jpg',
      's3Url': 'https://s3.amazonaws.com/file1.jpg',
      'fileId': 'file123',
      'originalName': 'screenshot.jpg',
      'size': 1024,
      'contentType': 'image/jpeg',
    }
  ],
  'voiceMessages': [
    {
      'uploadPath': 'https://s3.amazonaws.com/audio1.mp3',
      's3Url': 'https://s3.amazonaws.com/audio1.mp3',
      'fileId': 'audio123',
      'originalName': 'recording.mp3',
      'size': 2048,
      'contentType': 'audio/mpeg',
    }
  ],
});
```

### Working with Files

```dart
// Check file status
if (report.screenshots.isNotEmpty) {
  final firstFile = report.screenshots.first;
  
  if (firstFile.isComplete) {
    // File is fully uploaded to backend
    print('File URL: ${firstFile.displayUrl}');
    print('File name: ${firstFile.displayName}');
    print('File size: ${firstFile.size} bytes');
  } else if (firstFile.isLocalPath) {
    // File is only stored locally
    print('Local file: ${firstFile.uploadPath}');
  }
}

// Get display information for UI
final fileInfo = FileHandlingService.getFileDisplayInfo(report.screenshots);
for (final info in fileInfo) {
  print('${info['name']} - ${info['type']} (${info['size']} bytes)');
}
```

### Synchronization

```dart
// Check if files need uploading
if (FileHandlingService.hasUnuploadedFiles(report.screenshots)) {
  final unuploadedFiles = FileHandlingService.getUnuploadedFiles(report.screenshots);
  print('${unuploadedFiles.length} files need uploading');
}

// Convert to backend format for API calls
final backendFormat = FileHandlingService.toBackendFormat(report.screenshots);
```

## File Types Supported

### Images
- PNG, JPG, JPEG, GIF, BMP, WebP

### Documents  
- PDF, DOC, DOCX, TXT

### Audio
- MP3, WAV, M4A

### Video
- MP4

## Migration Notes

### From String Arrays
If you were previously using:
```dart
List<String> screenshots = ['/path1.jpg', '/path2.pdf'];
```

Now use:
```dart
List<FileModel> screenshots = [
  FileModel.fromString('/path1.jpg'),
  FileModel.fromString('/path2.pdf'),
];
```

### From Backend Responses
The models automatically handle the conversion from backend file objects to `FileModel` instances.

## Benefits

1. **Unified File Handling**: Same interface for online and offline files
2. **Automatic Format Detection**: Models automatically detect and handle different file formats
3. **Better Metadata**: Access to file size, type, and other metadata
4. **Seamless Sync**: Easy transition between offline and online modes
5. **Type Safety**: Strong typing with Hive support for local storage

## Next Steps

1. Run `dart run build_runner build` to generate Hive adapters
2. Update your UI code to use the new file display methods
3. Test offline/online synchronization
4. Update any custom file handling logic to use the new service
