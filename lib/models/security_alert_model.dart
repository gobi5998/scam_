enum AlertSeverity { low, medium, high, critical }
enum AlertType { spam, malware, fraud, phishing, other }

class SecurityAlert {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final AlertType type;
  final DateTime timestamp;
  final bool isResolved;
  final String? location;
  final Map<String, dynamic>? metadata;

  SecurityAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.type,
    required this.timestamp,
    required this.isResolved,
    this.location,
    this.metadata,
  });

  factory SecurityAlert.fromJson(Map<String, dynamic> json) {
    return SecurityAlert(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      severity: AlertSeverity.values.firstWhere(
        (e) => e.toString().split('.').last == json['severity'],
        orElse: () => AlertSeverity.medium,
      ),
      type: AlertType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AlertType.other,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      isResolved: json['is_resolved'] ?? false,
      location: json['location'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'severity': severity.toString().split('.').last,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'is_resolved': isResolved,
      'location': location,
      'metadata': metadata,
    };
  }

  String get severityColor {
    switch (severity) {
      case AlertSeverity.low:
        return '#4CAF50';
      case AlertSeverity.medium:
        return '#FF9800';
      case AlertSeverity.high:
        return '#F44336';
      case AlertSeverity.critical:
        return '#9C27B0';
    }
  }

  String get severityText {
    switch (severity) {
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }
} 