class ReportsFilter {
  final int? page;
  final int? limit;
  final String? reportCategoryId;
  final String? reportTypeId;
  final String? deviceTypeId;
  final String? detectTypeId;
  final String? operatingSystemName;
  final String? search;
  final DateTime? startDate;
  final DateTime? endDate;

  ReportsFilter({
    this.page,
    this.limit,
    this.reportCategoryId,
    this.reportTypeId,
    this.deviceTypeId,
    this.detectTypeId,
    this.operatingSystemName,
    this.search,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toQueryParameters() {
    final Map<String, dynamic> params = {};

    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();
    if (reportCategoryId != null) params['reportCategoryId'] = reportCategoryId;
    if (reportTypeId != null) params['reportTypeId'] = reportTypeId;
    if (deviceTypeId != null) params['deviceTypeId'] = deviceTypeId;
    if (detectTypeId != null) params['detectTypeId'] = detectTypeId;
    if (operatingSystemName != null) {
      params['operatingSystemName'] = operatingSystemName;
    }
    if (search != null && search!.isNotEmpty) {
      params['search'] = search;
    }
    if (startDate != null) {
      params['startDate'] = startDate!.toIso8601String();
    }
    if (endDate != null) {
      params['endDate'] = endDate!.toIso8601String();
    }
    return params;
  }

  String buildUrl() {
    final params = toQueryParameters();
    if (params.isEmpty) return '/api/v1/reports';

    final queryString = params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');

    return '/api/v1/reports?$queryString';
  }

  @override
  String toString() {
    return 'ReportsFilter(page: $page, limit: $limit, reportCategoryId: $reportCategoryId, reportTypeId: $reportTypeId, deviceTypeId: $deviceTypeId, detectTypeId: $detectTypeId, operatingSystemName: $operatingSystemName, search: $search, startDate: $startDate, endDate: $endDate)';
  }
}
