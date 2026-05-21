import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/provider_app_bar.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_drawer.dart';
import '../providers/locale_provider.dart';
import '../providers/provider_dashboard_provider.dart';

class ProviderEarningsScreen extends ConsumerWidget {
  const ProviderEarningsScreen({super.key});

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kSurfaceColor = Color(0xFF161B2E);
  static const Color _kAccentCyan = Color(0xFF00D1FF);
  static const Color _kHintTextColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.read(localeProvider.notifier).translate;
    final dashboardData = ref.watch(providerDashboardProvider);
    final isDark = ref.watch(localeProvider).isDarkMode;

    final bgColor = isDark ? _kBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kSurfaceColor : Colors.white;
    final subTextColor = isDark ? _kHintTextColor : const Color(0xFF64748B);
    final balanceCardGradient = isDark 
        ? const LinearGradient(colors: [Color(0xFF1E2435), Color(0xFF12151C)])
        : const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF4338CA)]);
    final balanceTextCol = Colors.white;
    final balanceSubTextCol = isDark ? _kHintTextColor : Colors.white70;
    final balanceBorder = isDark ? Border.all(color: _kAccentCyan.withOpacity(0.3)) : null;
    final withdrawBtnBg = isDark ? _kAccentCyan : Colors.white;
    final withdrawBtnFg = isDark ? _kBackgroundColor : const Color(0xFF4F46E5);
    final cardBorder = isDark ? null : Border.all(color: const Color(0xFFE2E8F0));

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const ProviderDrawer(),
      appBar: ProviderAppBar(title: translate('earnings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: balanceCardGradient,
                borderRadius: BorderRadius.circular(24),
                border: balanceBorder,
                boxShadow: [
                  if (!isDark)
                    BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  Text(translate('total_balance'), style: TextStyle(color: balanceSubTextCol, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Text('Rs. ${(dashboardData.todayEarnings * 5.2).toStringAsFixed(0)}', style: GoogleFonts.inter(color: balanceTextCol, fontSize: 40, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // 7-Day Earnings Chart
            Container(
              height: 250,
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
                  Text(translate('last_7_days'), style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
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
                                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                if (value >= 0 && value < days.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(days[value.toInt()], style: TextStyle(color: subTextColor, fontSize: 10)),
                                  );
                                }
                                  return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _makeGroupData(0, dashboardData.todayEarnings > 0 ? 1.2 : 0, isDark),
                          _makeGroupData(1, dashboardData.todayEarnings > 0 ? 2.5 : 0, isDark),
                          _makeGroupData(2, dashboardData.todayEarnings > 0 ? 1.8 : 0, isDark),
                          _makeGroupData(3, dashboardData.todayEarnings > 0 ? 3.2 : 0, isDark),
                          _makeGroupData(4, dashboardData.todayEarnings > 0 ? 2.8 : 0, isDark),
                          _makeGroupData(5, dashboardData.todayEarnings > 0 ? 4.5 : 0, isDark),
                          _makeGroupData(6, dashboardData.todayEarnings > 0 ? 3.8 : 0, isDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            _buildEarningRow(translate('today_earnings'), 'Rs. ${dashboardData.todayEarnings.toStringAsFixed(0)}', '+12%', isDark),
            _buildEarningRow('This Week', 'Rs. ${(dashboardData.todayEarnings * 3.4).toStringAsFixed(0)}', '+5%', isDark),
            _buildEarningRow('This Month', 'Rs. ${(dashboardData.todayEarnings * 15.2).toStringAsFixed(0)}', '+18%', isDark),
          ],
        ),
      ),
      bottomNavigationBar: const ProviderBottomNav(currentIndex: 2),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, bool isDark) {
    final barBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final accentCyan = isDark ? _kAccentCyan : const Color(0xFF4F46E5);

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: accentCyan,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 5,
            color: barBg,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningRow(String period, String amount, String growth, bool isDark) {
    final rowBg = isDark ? _kSurfaceColor : Colors.white;
    final titleCol = isDark ? _kHintTextColor : const Color(0xFF64748B);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? null : Border.all(color: const Color(0xFFE2E8F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(period, style: TextStyle(color: titleCol, fontSize: 14)),
                const SizedBox(height: 4),
                Text(amount, style: TextStyle(color: textCol, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(growth, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
