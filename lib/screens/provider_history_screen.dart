import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/provider_app_bar.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_drawer.dart';
import '../providers/provider_dashboard_provider.dart';
import '../providers/locale_provider.dart';

class ProviderHistoryScreen extends ConsumerWidget {
  const ProviderHistoryScreen({super.key});

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);
  static const Color _kDarkHintTextColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final jobs = ref.watch(providerDashboardProvider).recentJobs;

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final accentColor = isDark ? _kDarkAccentCyan : const Color(0xFF4F46E5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintTextColor = isDark ? _kDarkHintTextColor : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: const ProviderDrawer(),
      appBar: const ProviderAppBar(title: 'Job History'),
      body: jobs.isEmpty 
        ? Center(child: Text('No job history found.', style: TextStyle(color: hintTextColor)))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.build_outlined, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.serviceType, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          Text(job.location, style: TextStyle(color: hintTextColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(job.priceEstimate, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        Text(
                          job.status.toUpperCase(),
                          style: TextStyle(
                            color: job.status == 'COMPLETED' ? (isDark ? _kDarkAccentCyan : Colors.green.shade600) : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      bottomNavigationBar: const ProviderBottomNav(currentIndex: 1),
    );
  }
}

