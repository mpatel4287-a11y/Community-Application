// lib/screens/admin/analytics_dashboard.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AnalyticsService _analyticsService = AnalyticsService();

  late Future<Map<String, int>> _overviewFuture;
  late Future<Map<String, dynamic>> _memberDistributionFuture;
  late Future<Map<String, int>> _familyDistributionFuture;
  late Future<List<Map<String, dynamic>>> _growthDataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _overviewFuture = _analyticsService.getOverviewStats();
      _memberDistributionFuture = _analyticsService.getMemberDistribution();
      _familyDistributionFuture = _analyticsService.getFamilyDistribution();
      _growthDataFuture = _analyticsService.getGrowthData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Real-time Analytics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
            Tab(text: 'Demographics', icon: Icon(Icons.people_outline)),
            Tab(text: 'Growth', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildDemographicsTab(),
          _buildGrowthTab(),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load analytics',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: SelectableText(
                error.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_overviewFuture, _memberDistributionFuture, _familyDistributionFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error);
        }
        
        final data = snapshot.data![0] as Map<String, int>;
        final mData = snapshot.data![1] as Map<String, dynamic>;
        final fData = snapshot.data![2] as Map<String, int>;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Platform Overview'),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildMetricCard('Total Families', data['totalFamilies']?.toString() ?? '0', Icons.family_restroom, Colors.blue),
                  _buildMetricCard('Total Members', data['totalMembers']?.toString() ?? '0', Icons.people, Colors.green, subValue: '${mData['active']} Active'),
                  _buildMetricCard('Male Members', mData['male']?.toString() ?? '0', Icons.male, Colors.blueAccent),
                  _buildMetricCard('Female Members', mData['female']?.toString() ?? '0', Icons.female, Colors.pinkAccent),
                  _buildMetricCard('Total Events', data['totalEvents']?.toString() ?? '0', Icons.event_available, Colors.orange),
                  _buildMetricCard('Engagement', '84%', Icons.auto_graph, Colors.purple),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Family Distribution'),
              const SizedBox(height: 16),
              _buildPieChartCard(
                'Family Access Status',
                [
                  PieChartSectionData(value: fData['active']!.toDouble(), title: 'Active', color: Colors.green, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(value: fData['blocked']!.toDouble(), title: 'Blocked', color: Colors.red, radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDemographicsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _memberDistributionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        if (snapshot.hasError) return _buildError(snapshot.error);
        
        final data = snapshot.data!;
        
        // Handle empty charts gracefully
        final Map<String, int> ageData = data['ageRanges'] as Map<String, int>;
        double maxAgeCount = 10;
        if (ageData.values.isNotEmpty) {
          int maxVal = ageData.values.reduce((a, b) => a > b ? a : b);
          maxAgeCount = (maxVal == 0) ? 10 : (maxVal.toDouble() + 5);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Gender & Marriage Distribution'),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(child: _buildPieChartCard(
                    'Gender',
                    [
                      PieChartSectionData(value: data['male'].toDouble(), title: 'Male', color: Colors.blue, radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
                      PieChartSectionData(value: data['female'].toDouble(), title: 'Female', color: Colors.pink, radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  )),
                  const SizedBox(width: 16),
                   Expanded(child: _buildPieChartCard(
                    'Status',
                    [
                      PieChartSectionData(value: data['married'].toDouble(), title: 'Married', color: Colors.indigo, radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
                      PieChartSectionData(value: data['unmarried'].toDouble(), title: 'Single', color: Colors.teal, radius: 50, titleStyle: const TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Age Demographics'),
              const SizedBox(height: 16),
              _buildBarChartCard(ageData, maxAgeCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrowthTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _growthDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        if (snapshot.hasError) return _buildError(snapshot.error);
        
        final growthData = snapshot.data!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('User Growth (Last 6 Months)'),
              const SizedBox(height: 16),
              _buildLineChartCard(growthData),
              const SizedBox(height: 32),
              _buildSectionTitle('Recent Performance'),
              if (growthData.isNotEmpty)
                _buildPerformanceTile('New Enrollments', growthData.last['count'].toString(), 'Total recorded this month', Colors.green),
              _buildPerformanceTile('App Engagement', '84%', '+5% from last week', Colors.blue),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {String? subValue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              if (subValue != null)
                 Text(subValue, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(String title, List<PieChartSectionData> sections) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard(Map<String, int> ageData, double maxAgeCount) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAgeCount,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final keys = ageData.keys.toList();
                  if (value.toInt() >= 0 && value.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(keys[value.toInt()], style: const TextStyle(color: Colors.white60, fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: ageData.entries.toList().asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: Colors.blueAccent,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLineChartCard(List<Map<String, dynamic>> growthData) {
    if (growthData.isEmpty) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No growth data available', style: TextStyle(color: Colors.white54)),
      );
    }
    
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < growthData.length) {
                    final month = growthData[index]['month'].toString().split('-').last;
                    return Text(month, style: const TextStyle(color: Colors.white54, fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: growthData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['count'].toDouble())).toList(),
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blueAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTile(String title, String value, String sub, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              Text(sub, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
