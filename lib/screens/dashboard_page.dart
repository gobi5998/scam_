import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:security_alert/custom/Image/image.dart';
import 'package:security_alert/screens/Fraud/ReportFraudStep1.dart';
import 'package:security_alert/screens/scam/report_scam_1.dart';
import 'package:security_alert/screens/scam/scam_report_service.dart';
import '../custom/bottomnavigation.dart';
import '../custom/customButton.dart';
import '../provider/dashboard_provider.dart';
import '../widget/graph_widget.dart';
import '../widget/Drawer/appDrawer.dart';
import '../services/biometric_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_widget.dart';
import '../config/api_config.dart';
import 'ReportedFeatureCard.dart';
import 'ReportedFeatureItem.dart';
import 'alert.dart';
import 'malware/report_malware_1.dart';
import 'menu/theard_database.dart';
import 'server_reports_page.dart';
import 'menu/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(
    debugLabel: 'dashboard_scaffold',
  );
  List<Map<String, dynamic>> reportTypes = [];
  bool isLoadingTypes = true;
  List<Map<String, dynamic>> reportCategories = [];
  bool isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    // Load dashboard data when the page is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(
        context,
        listen: false,
      ).loadDashboardData();
    });
    _loadReportTypes();
    _loadReportCategories();

    // Test API connection
    _testApiConnection();
  }

  Future<void> _testApiConnection() async {
    try {
      print('🧪 Testing API connection for report categories...');

      final categories = await ScamReportService.fetchReportCategories();
      print('✅ API test successful - found ${categories.length} categories');

      for (var category in categories) {
        print('📋 Category: ${category['name']} -> ID: ${category['_id']}');
      }

      // Show a snackbar with the results for debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'API Test: Found ${categories.length} categories from backend',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ API test failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API Test Failed: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadReportTypes() async {
    reportTypes = await ScamReportService.fetchReportTypes();
    print('report$reportTypes');
    setState(() {
      isLoadingTypes = false;
    });
  }

  Future<void> _loadReportCategories() async {
    try {
      print('🔍 Attempting to load report categories from API...');
      print(
        '🔍 Full endpoint: ${ApiConfig.mainBaseUrl}${ApiConfig.reportCategoryEndpoint}',
      );

      reportCategories = await ScamReportService.fetchReportCategories();
      print('✅ Loaded categories from API: $reportCategories');

      // Only use API response, no fallback
      if (reportCategories.isNotEmpty) {
        print(
          '✅ Successfully loaded ${reportCategories.length} categories from API',
        );
        for (var category in reportCategories) {
          print('📋 Category: ${category['name']} -> ID: ${category['_id']}');
        }
      } else {
        print('⚠️ API returned empty categories');
        reportCategories = [];

        // Show user-friendly error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No categories found. Please check your ngrok tunnel.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e.toString().contains('SocketException')) {
        print('❌ Network connection issue - check ngrok tunnel');
      } else if (e.toString().contains('TimeoutException')) {
        print('❌ Request timeout - check ngrok tunnel');
      } else if (e.toString().contains('HttpException')) {
        print('❌ HTTP error - check ngrok tunnel and backend server');
      }

      reportCategories = [];

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    setState(() {
      isLoadingCategories = false;
    });
    print('✅ Categories loading completed. Count: ${reportCategories.length}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    return ResponsiveScaffold(
      key: _scaffoldKey,
      drawer: const DashboardDrawer(),
      extendBody: true,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.center,
              colors: <Color>[
                Color(0xFF064FAD), // Darker blue
                Color(0xFF064FAD),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Security Alert",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 24),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {},
              ),
            ],
          ),
          IconButton(
            icon: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'i',
                  style: TextStyle(
                    color: Color(0xFF064FAD),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Color(0xFFf0f2f5)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Report buttons row (separate from nav bar)
            Padding(
              padding: ResponsiveHelper.getResponsiveEdgeInsets(context, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.getResponsivePadding(
                          context,
                          1,
                        ),
                      ),
                      child: CustomButton(
                        text: isLoadingCategories
                            ? 'Loading...'
                            : 'Report Scam',
                        height: ResponsiveHelper.getResponsivePadding(
                          context,
                          56,
                        ),
                        isLoading: isLoadingCategories,
                        onPressed: () async {
                          if (isLoadingCategories) return;

                          if (reportCategories.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No categories available. Please check your connection and try again.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Map<String, dynamic>? scamCategory;
                          try {
                            scamCategory = reportCategories.firstWhere(
                              (e) =>
                                  e['name']?.toString().toLowerCase().contains(
                                    'scam',
                                  ) ==
                                  true,
                            );
                          } catch (_) {
                            scamCategory = null;
                          }

                          // If category not found, show error
                          if (scamCategory == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Scam category not found in API response. Available categories: ${reportCategories.map((c) => c['name']).join(', ')}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          print(
                            '🎯 Navigating to Report Scam with category ID: ${scamCategory!['_id']}',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReportScam1(categoryId: scamCategory!['_id']),
                            ),
                          );
                        },
                        fontWeight: FontWeight.w600,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.getResponsivePadding(
                          context,
                          1,
                        ),
                      ),
                      child: CustomButton(
                        text: isLoadingCategories
                            ? 'Loading...'
                            : 'Report Malware',
                        height: ResponsiveHelper.getResponsivePadding(
                          context,
                          56,
                        ),
                        isLoading: isLoadingCategories,
                        onPressed: () async {
                          if (isLoadingCategories) return;

                          if (reportCategories.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No categories available. Please check your connection and try again.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Map<String, dynamic>? malwareCategory;
                          try {
                            malwareCategory = reportCategories.firstWhere(
                              (e) =>
                                  e['name']?.toString().toLowerCase().contains(
                                    'malware',
                                  ) ==
                                  true,
                            );
                          } catch (_) {
                            malwareCategory = null;
                          }

                          // If category not found, show error
                          if (malwareCategory == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Malware category not found in API response. Available categories: ${reportCategories.map((c) => c['name']).join(', ')}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          print(
                            '🎯 Navigating to Report Malware with category ID: ${malwareCategory!['_id']}',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportMalware1(
                                categoryId: malwareCategory!['_id'],
                              ),
                            ),
                          );
                        },
                        fontWeight: FontWeight.w600,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.getResponsivePadding(
                          context,
                          1,
                        ),
                      ),
                      child: CustomButton(
                        text: isLoadingCategories
                            ? 'Loading...'
                            : 'Report Fraud',
                        height: ResponsiveHelper.getResponsivePadding(
                          context,
                          56,
                        ),
                        isLoading: isLoadingCategories,
                        onPressed: () async {
                          if (isLoadingCategories) return;

                          if (reportCategories.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No categories available. Please check your connection and try again.',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Map<String, dynamic>? fraudCategory;
                          try {
                            fraudCategory = reportCategories.firstWhere(
                              (e) =>
                                  e['name']?.toString().toLowerCase().contains(
                                    'fraud',
                                  ) ==
                                  true,
                            );
                          } catch (_) {
                            fraudCategory = null;
                          }

                          // If category not found, show error
                          if (fraudCategory == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Fraud category not found in API response. Available categories: ${reportCategories.map((c) => c['name']).join(', ')}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          print(
                            '🎯 Navigating to Report Fraud with category ID: ${fraudCategory!['_id']}',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReportFraudStep1(
                                categoryId: fraudCategory!['_id'],
                              ),
                            ),
                          );
                        },
                        fontWeight: FontWeight.w600,
                        fontSize: ResponsiveHelper.getResponsiveFontSize(
                          context,
                          12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom navigation bar
            BottomNavigationBar(
              backgroundColor: Color(0xFFf0f2f5),
              elevation: 8,
              selectedItemColor: Colors.black,
              items: [
                customBottomNavItem(BottomNav: BottomNav.home, label: 'Home'),
                customBottomNavItem(BottomNav: BottomNav.alert, label: 'Alert'),
                customBottomNavItem(
                  BottomNav: BottomNav.profile,
                  label: 'Profile',
                ),
              ],
              onTap: (index) {
                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ThreadDatabaseFilterPage(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage()),
                  );
                }
                // Do nothing for Home (index 0)
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF064FAD), // Deep blue at the top
              Color(0xFFB8D4F5), // Light bluish-white fade in between
              Color(0xFFFFFFFF), // White at the bottom
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: ListView(
                        children: [
                          const SizedBox(height: 8),

                          // Carousel
                          Container(
                            padding: ResponsiveHelper.getResponsiveEdgeInsets(
                              context,
                              16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: ResponsiveHelper.getResponsivePadding(
                                    context,
                                    16,
                                  ),
                                ),

                                // Carousel Slider with Auto Scroll
                                CarouselSlider(
                                  options: CarouselOptions(
                                    height:
                                        ResponsiveHelper.getResponsivePadding(
                                          context,
                                          200,
                                        ),
                                    enlargeCenterPage: true,
                                    enableInfiniteScroll: true,
                                    autoPlay: true,
                                    autoPlayInterval: const Duration(
                                      seconds: 3,
                                    ),
                                    autoPlayAnimationDuration: const Duration(
                                      milliseconds: 800,
                                    ),
                                    autoPlayCurve: Curves.fastOutSlowIn,
                                    viewportFraction: 0.8,
                                    aspectRatio: 16 / 9,
                                  ),
                                  items:
                                      [
                                        "assets/image/security1.jpg",
                                        "assets/image/security2.png",
                                        "assets/image/security3.jpg",
                                        "assets/image/security4.jpg",
                                        "assets/image/security5.jpg",
                                        "assets/image/security6.jpg",
                                      ].map((imagePath) {
                                        return Builder(
                                          builder: (BuildContext context) {
                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Image.asset(
                                                  imagePath,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              16,
                            ),
                          ),

                          // Reported Features Panel with Responsive Design
                          Container(
                            padding: ResponsiveHelper.getResponsiveEdgeInsets(
                              context,
                              16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Reported Features',
                                      style: TextStyle(
                                        fontSize:
                                            ResponsiveHelper.getResponsiveFontSize(
                                              context,
                                              18,
                                            ),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    Container(
                                      padding:
                                          ResponsiveHelper.getResponsiveEdgeInsets(
                                            context,
                                            8,
                                          ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade800,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Weekly',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize:
                                                  ResponsiveHelper.getResponsiveFontSize(
                                                    context,
                                                    12,
                                                  ),
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                          SizedBox(
                                            width:
                                                ResponsiveHelper.getResponsivePadding(
                                                  context,
                                                  4,
                                                ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.white,
                                            size:
                                                ResponsiveHelper.getResponsiveFontSize(
                                                  context,
                                                  16,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: ResponsiveHelper.getResponsivePadding(
                                    context,
                                    16,
                                  ),
                                ),
                                // Feature items will be handled by ReportedFeaturesPanel
                                ReportedFeaturesPanel(),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              16,
                            ),
                          ),

                          // Stats
                          Container(
                            margin: EdgeInsets.symmetric(
                              vertical: ResponsiveHelper.getResponsivePadding(
                                context,
                                8,
                              ),
                            ),
                            padding: ResponsiveHelper.getResponsiveEdgeInsets(
                              context,
                              20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Thread Statistics",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize:
                                        ResponsiveHelper.getResponsiveFontSize(
                                          context,
                                          18,
                                        ),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(
                                  height: ResponsiveHelper.getResponsivePadding(
                                    context,
                                    18,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: '50K+',
                                        desc: 'Scams Reported',
                                        highlight: true,
                                      ),
                                    ),
                                    SizedBox(
                                      width:
                                          ResponsiveHelper.getResponsivePadding(
                                            context,
                                            8,
                                          ),
                                    ),
                                    Expanded(
                                      child: _StatCard(
                                        label: '10K+',
                                        desc: 'Malware Samples',
                                        highlight: true,
                                      ),
                                    ),
                                    SizedBox(
                                      width:
                                          ResponsiveHelper.getResponsivePadding(
                                            context,
                                            8,
                                          ),
                                    ),
                                    Expanded(
                                      child: _StatCard(
                                        label: '24/7',
                                        desc: 'Threat Monitoring',
                                        highlight: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              16,
                            ),
                          ),

                          // Thread Analysis Card
                          ThreadAnalysisCard(),

                          SizedBox(
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, desc;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.desc,
    this.highlight = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ResponsiveHelper.getResponsivePadding(context, 90),
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.getResponsivePadding(context, 1),
      ),
      padding: ResponsiveHelper.getResponsiveEdgeInsets(context, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF064FAD),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: ResponsiveHelper.getResponsivePadding(context, 4)),
          Text(
            desc,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white70,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 8),
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
