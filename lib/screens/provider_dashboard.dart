import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_drawer.dart';
import '../widgets/provider_app_bar.dart';

class ProviderDashboard extends ConsumerStatefulWidget {
  const ProviderDashboard({super.key});
  @override
  ConsumerState<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends ConsumerState<ProviderDashboard> {
  bool isOnline = true;

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kSurfaceColor = Color(0xFF161B2E);
  static const Color _kAccentCyan = Color(0xFF00D1FF);
  static const Color _kHintTextColor = Color(0xFF6B7280);
  static const Color _kCardColor = Color(0xFF1E2435);

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final dashboardData = ref.watch(providerDashboardProvider);
    final translate = ref.read(localeProvider.notifier).translate;
    final isDark = locale.isDarkMode;

    final bgColor = isDark ? _kBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kSurfaceColor : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? _kHintTextColor : const Color(0xFF64748B);
    final appbarTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final accentCyan = isDark ? _kAccentCyan : const Color(0xFF4F46E5);
    final statusBorder = isDark 
        ? Border.all(color: isOnline ? _kAccentCyan.withValues(alpha: 0.5) : Colors.white10)
        : Border.all(color: isOnline ? const Color(0xFF4F46E5).withValues(alpha: 0.3) : const Color(0xFFE2E8F0));

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const ProviderDrawer(),
      appBar: const ProviderAppBar(title: 'HAAZIR'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(providerDashboardProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (locale.isMockMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    translate('mock_disclaimer'),
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 10),
              // Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: statusBorder,
                  boxShadow: [
                    if (isOnline)
                      BoxShadow(color: accentCyan.withOpacity(0.1), blurRadius: 15, spreadRadius: 2),
                    if (!isDark)
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOnline ? accentCyan.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wifi, color: isOnline ? accentCyan : subTextColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(translate('status'), style: TextStyle(color: subTextColor, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            '${translate('status_msg')} ${isOnline ? translate('online') : translate('offline')}',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: isOnline,
                      activeColor: accentCyan,
                      onChanged: (val) => setState(() => isOnline = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(translate('today_earnings'), "Rs. ${dashboardData.todayEarnings.toStringAsFixed(0)}", Icons.account_balance_wallet_outlined, onTap: () => context.go('/provider_earnings')),
                  _buildStatCard(translate('jobs_done'), dashboardData.jobsDone.toString(), Icons.check_circle_outline),
                  _buildStatCard(translate('acceptance'), "${dashboardData.acceptanceRate.toStringAsFixed(0)} %", Icons.verified_outlined),
                  _buildStatCard(translate('avg_rating'), dashboardData.avgRating.toStringAsFixed(1), Icons.star_outline, onTap: () => context.push('/provider_evaluation')),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 20, color: accentCyan),
                      const SizedBox(width: 10),
                      Text(
                        translate('recent_jobs'),
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (!locale.isMockMode && dashboardData.recentJobs.isEmpty)
                    TextButton(
                      onPressed: () => ref.read(localeProvider.notifier).toggleMockMode(),
                      child: Text(translate('simulate'), style: TextStyle(color: accentCyan, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Recent Jobs List
              if (dashboardData.recentJobs.isEmpty && !locale.isMockMode)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_late_outlined, color: subTextColor, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          translate('no_data_available'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subTextColor),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => ref.read(localeProvider.notifier).toggleMockMode(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentCyan,
                            foregroundColor: isDark ? _kBackgroundColor : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Load Mock Data', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (dashboardData.recentJobs.isEmpty && locale.isMockMode)
                 Center(child: Text("Loading Mock Data...", style: TextStyle(color: textColor)))
              else
                ...dashboardData.recentJobs.map((job) => _buildRecentJob(
                      job.serviceType,
                      job.location,
                      job.priceEstimate,
                      job.status,
                      job.status == 'COMPLETED' ? accentCyan : Colors.redAccent,
                    )),
              const SizedBox(height: 20),
              if (locale.isMockMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        translate('mock_disclaimer'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => ref.read(localeProvider.notifier).toggleMockMode(),
                        child: Text('Turn Off Mock Mode', style: TextStyle(color: isDark ? Colors.white70 : Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ProviderBottomNav(currentIndex: 0),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {VoidCallback? onTap}) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final cardBg = isDark ? _kCardColor : Colors.white;
    final accentCyan = isDark ? _kAccentCyan : const Color(0xFF4F46E5);
    final titleColor = isDark ? _kHintTextColor : const Color(0xFF64748B);
    final valColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? null : Border.all(color: const Color(0xFFE2E8F0));

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: titleColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(icon, color: accentCyan, size: 16),
              ],
            ),
            Text(
              value,
              style: TextStyle(color: valColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentJob(String title, String area, String fare, String status, Color statusColor) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final surfaceBg = isDark ? _kSurfaceColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? _kHintTextColor : const Color(0xFF64748B);
    final accentCyan = isDark ? _kAccentCyan : const Color(0xFF4F46E5);
    final border = isDark ? null : Border.all(color: const Color(0xFFE2E8F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : accentCyan.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              title.contains("Wiring") ? Icons.bolt : Icons.build_outlined,
              color: accentCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: subTextColor, size: 12),
                    const SizedBox(width: 4),
                    Text(area, style: TextStyle(color: subTextColor, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fare, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
