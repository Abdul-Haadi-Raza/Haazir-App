import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/provider_bottom_nav.dart';
import '../providers/locale_provider.dart';
import '../providers/provider_dashboard_provider.dart';

class ProviderEvaluationScreen extends ConsumerWidget {
  const ProviderEvaluationScreen({super.key});

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kSurfaceColor = Color(0xFF161B2E);
  static const Color _kHintTextColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.read(localeProvider.notifier).translate;
    final dashboardData = ref.watch(providerDashboardProvider);
    final isDark = ref.watch(localeProvider).isDarkMode;

    final bgColor = isDark ? _kBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kSurfaceColor : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? _kHintTextColor : const Color(0xFF64748B);
    final cardBorder = isDark ? null : Border.all(color: const Color(0xFFE2E8F0));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(translate('performance'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: surfaceColor,
              child: const Icon(Icons.star, color: Colors.orangeAccent, size: 40),
            ),
            const SizedBox(height: 16),
            Text('${dashboardData.avgRating.toStringAsFixed(1)} Rating', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Based on ${dashboardData.jobsDone * 18} reviews', style: TextStyle(color: subTextColor)),
            
            const SizedBox(height: 40),
            
            // Ratings Distribution Chart
            Container(
              height: 200,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: cardBorder,
                boxShadow: [
                  if (!isDark)
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate('rating_dist'), style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text('${value.toInt() + 1}★', style: TextStyle(color: subTextColor, fontSize: 10));
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _makeRatingGroup(0, dashboardData.avgRating > 0 ? 5 : 0),
                          _makeRatingGroup(1, dashboardData.avgRating > 0 ? 2 : 0),
                          _makeRatingGroup(2, dashboardData.avgRating > 0 ? 10 : 0),
                          _makeRatingGroup(3, dashboardData.avgRating > 0 ? 45 : 0),
                          _makeRatingGroup(4, dashboardData.avgRating > 0 ? 85 : 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            if (dashboardData.recentJobs.isEmpty)
               Text(translate('no_data'), style: TextStyle(color: subTextColor))
            else
              ...dashboardData.recentJobs.map((job) => _buildReviewTile(
                job.customerName, 
                5, 
                'Great work on ${job.serviceType}! Very professional.',
                isDark
              )),
          ],
        ),
      ),
      bottomNavigationBar: const ProviderBottomNav(currentIndex: 3),
    );
  }

  BarChartGroupData _makeRatingGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: x >= 3 ? Colors.greenAccent : (x == 2 ? Colors.orangeAccent : Colors.redAccent),
          width: 20,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildReviewTile(String name, int rating, String comment, bool isDark) {
    final cardBg = isDark ? _kSurfaceColor : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white70 : const Color(0xFF334155);
    final border = isDark ? null : Border.all(color: const Color(0xFFE2E8F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, color: i < rating ? Colors.orangeAccent : Colors.white10, size: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment, style: TextStyle(color: subTextCol, fontSize: 13)),
        ],
      ),
    );
  }
}
