class DashboardStats {
  final int totalAlerts;
  final int resolvedAlerts;
  final int pendingAlerts;
  final Map<String, int> alertsByType;
  final Map<String, int> alertsBySeverity;
  final List<double> threatTrendData;
  final List<int> threatBarData;
  final double riskScore;

  DashboardStats({
    required this.totalAlerts,
    required this.resolvedAlerts,
    required this.pendingAlerts,
    required this.alertsByType,
    required this.alertsBySeverity,
    required this.threatTrendData,
    required this.threatBarData,
    required this.riskScore,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalAlerts: json['total_alerts'] ?? 0,
      resolvedAlerts: json['resolved_alerts'] ?? 0,
      pendingAlerts: json['pending_alerts'] ?? 0,
      alertsByType: Map<String, int>.from(json['alerts_by_type'] ?? {}),
      alertsBySeverity: Map<String, int>.from(json['alerts_by_severity'] ?? {}),
      threatTrendData: List<double>.from(json['threat_trend_data'] ?? []),
      threatBarData: List<int>.from(json['threat_bar_data'] ?? []),
      riskScore: (json['risk_score'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_alerts': totalAlerts,
      'resolved_alerts': resolvedAlerts,
      'pending_alerts': pendingAlerts,
      'alerts_by_type': alertsByType,
      'alerts_by_severity': alertsBySeverity,
      'threat_trend_data': threatTrendData,
      'threat_bar_data': threatBarData,
      'risk_score': riskScore,
    };
  }

  double get resolutionRate {
    if (totalAlerts == 0) return 0.0;
    return (resolvedAlerts / totalAlerts) * 100;
  }

  String get riskLevel {
    if (riskScore < 30) return 'Low';
    if (riskScore < 60) return 'Medium';
    if (riskScore < 80) return 'High';
    return 'Critical';
  }

  String get riskColor {
    if (riskScore < 30) return '#4CAF50';
    if (riskScore < 60) return '#FF9800';
    if (riskScore < 80) return '#F44336';
    return '#9C27B0';
  }
} 