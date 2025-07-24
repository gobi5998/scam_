import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:security_alert/custom/Image/image.dart';
import 'package:security_alert/screens/Fraud/ReportFraudStep1.dart';
import 'package:security_alert/screens/scam/report_scam_1.dart';
import 'package:security_alert/screens/scam/scam_report_service.dart';
import '../custom/PeriodDropdown.dart';
import '../custom/bottomnavigation.dart';
import '../custom/customButton.dart';
import '../provider/dashboard_provider.dart';
import '../widget/graph_widget.dart';
import '../widget/Drawer/appDrawer.dart';
import '../services/biometric_service.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      print('🔍 Attempting to load report categories...');
      reportCategories = await ScamReportService.fetchReportCategories();
      print('✅ Loaded categories: $reportCategories'); // Debug print

      // If API fails or returns empty, provide fallback categories
      if (reportCategories.isEmpty) {
        print('⚠️ API returned empty categories, using fallback');
        reportCategories = [
          {'_id': 'scam_category', 'name': 'Report Scam'},
          {'_id': 'malware_category', 'name': 'Report Malware'},
          {'_id': 'fraud_category', 'name': 'Report Fraud'},
        ];
        print('📋 Using fallback categories: $reportCategories');
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
      // Provide fallback categories on error
      reportCategories = [
        {'_id': 'scam_category', 'name': 'Report Scam'},
        {'_id': 'malware_category', 'name': 'Report Malware'},
        {'_id': 'fraud_category', 'name': 'Report Fraud'},
      ];
      print('📋 Using fallback categories due to error: $reportCategories');
    }

    setState(() {
      isLoadingCategories = false;
    });
    print('✅ Categories loading completed. Count: ${reportCategories.length}');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    return Scaffold(
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
        title: const Text(
          "Security Alert",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 18,
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
              // Positioned(
              //   right: 8,
              //   top: 8,
              //   child: Container(
              //     width: 8,
              //     height: 8,
              //     decoration: const BoxDecoration(
              //       color: Colors.red,
              //       shape: BoxShape.circle,
              //     ),
              //   ),
              // ),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: CustomButton(
                        text: 'Report Scam',
                        onPressed: () async {
                          if (isLoadingTypes) return;

                          Map<String, dynamic>? scamCategory;
                          try {
                            scamCategory = reportCategories.firstWhere(
                              (e) => e['name'] == 'Report Scam',
                            );
                          } catch (_) {
                            scamCategory = null;
                          }

                          // If category not found, use fallback
                          if (scamCategory == null) {
                            scamCategory = {'_id': 'scam_category'};
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ReportScam1(categoryId: scamCategory!['_id']),
                            ),
                          );
                        },
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: CustomButton(
                        text: 'Report Malware',
                        onPressed: () async {
                          if (isLoadingCategories) return;

                          Map<String, dynamic>? malwareCategory;
                          try {
                            malwareCategory = reportCategories.firstWhere(
                              (e) => e['name'] == 'Report Malware',
                            );
                          } catch (_) {
                            malwareCategory = null;
                          }

                          // If category not found, use fallback
                          if (malwareCategory == null) {
                            malwareCategory = {'_id': 'malware_category'};
                          }

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
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: CustomButton(
                        text: 'Report Fraud',
                        onPressed: () async {
                          if (isLoadingCategories) return;

                          Map<String, dynamic>? fraudCategory;
                          try {
                            fraudCategory = reportCategories.firstWhere(
                              (e) => e['name'] == 'Report Fraud',
                            );
                          } catch (_) {
                            fraudCategory = null;
                          }

                          // If category not found, use fallback
                          if (fraudCategory == null) {
                            fraudCategory = {'_id': 'fraud_category'};
                          }

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
          gradient: const LinearGradient(
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

                          // Show error message
                          if (provider.errorMessage.isNotEmpty)
                            // Carousel
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),

                              child: CarouselSlider(
                                options: CarouselOptions(
                                  height: 170.0,
                                  enlargeCenterPage: true,
                                  enableInfiniteScroll: true,
                                  autoPlay: true,
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
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.asset(
                                              imagePath,
                                              fit: BoxFit.cover,
                                              width: MediaQuery.of(
                                                context,
                                              ).size.width,
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                              ),
                            ),

                          // ScamCarousel(),
                          const SizedBox(height: 16),

                          // Feature stats
                          // Container(
                          //   padding: const EdgeInsets.all(16),
                          //   decoration: BoxDecoration(
                          //     color: Colors.black.withOpacity(0.2),
                          //     borderRadius: BorderRadius.circular(16),
                          //   ),
                          //   child: Column(
                          //     children: provider.reportedFeatures.entries.map((
                          //       entry,
                          //     ) {
                          //       return Padding(
                          //         padding: const EdgeInsets.symmetric(
                          //           vertical: 8.0,
                          //         ),
                          //         child: Row(
                          //           children: [
                          //             Expanded(flex: 2, child: Text(entry.key)),
                          //             Expanded(
                          //               flex: 5,
                          //               child: LinearProgressIndicator(
                          //                 value: (entry.value is int)
                          //                     ? entry.value.toDouble()
                          //                     : entry.value,
                          //                 color: Colors.blue,
                          //                 backgroundColor: Colors.white,
                          //               ),
                          //             ),
                          //             const SizedBox(width: 8),
                          //             Text("${(entry.value * 100).toInt()}%"),
                          //           ],
                          //         ),
                          //       );
                          //     }).toList(),
                          //   ),
                          // ),
                          ReportedFeaturesPanel(),
                          const SizedBox(height: 16),

                          // Stats
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Thread Statistics",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
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
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _StatCard(
                                        label: '10K+',
                                        desc: 'Malware Samples',
                                        highlight: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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

                          const SizedBox(height: 16),

                          ThreadAnalysisCard(),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                // Loading overlay
                if (provider.isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// class _ReportButton extends StatelessWidget {
//   final String label;
//   final IconData icon;
//
//   const _ReportButton({required this.label, required this.icon});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         CircleAvatar(
//           radius: 26,
//           backgroundColor: Colors.white,
//           child: Icon(icon, color: Color(0xFF1E3A8A)),
//         ),
//         const SizedBox(height: 6),
//         Text(
//           label,
//           style: const TextStyle(color: Colors.white, fontSize: 12),
//         ),
//       ],
//     );
//   }
// }
//
// class _BottomReportButton extends StatelessWidget {
//   final String label;
//   const _BottomReportButton({required this.label});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(color: Color(0xFF064FAD), fontWeight: FontWeight.bold),
//       ),
//     );
//   }
// }
