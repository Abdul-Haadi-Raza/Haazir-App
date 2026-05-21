import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/provider_bottom_nav.dart';
import '../providers/locale_provider.dart';
import '../providers/booking_provider.dart';

class ProviderJobsScreen extends ConsumerWidget {
  const ProviderJobsScreen({super.key});

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);
  static const Color _kDarkHintTextColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final bookingState = ref.watch(bookingProvider);

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final accentColor = isDark ? _kDarkAccentCyan : const Color(0xFF4F46E5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final hintTextColor = isDark ? _kDarkHintTextColor : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    // Watch dynamic active booking
    final dynamicBooking = bookingState.result?.booking;
    final hasActiveDynamicJob = dynamicBooking != null && dynamicBooking.status == 'active';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('Job Requests', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Job', style: TextStyle(color: textSecondaryColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildActiveJobCard(
              context,
              ref,
              hasActiveDynamicJob ? dynamicBooking.serviceType : 'Leaky Sink Repair',
              hasActiveDynamicJob ? dynamicBooking.priceEstimate : 'Rs. 1,500',
              hasActiveDynamicJob ? dynamicBooking.customerName : 'Ahmad Raza',
              hasActiveDynamicJob ? dynamicBooking.bookingId : 'mock_id_123',
              isDark,
              backgroundColor,
              surfaceColor,
              accentColor,
              textColor,
              hintTextColor,
              borderColor,
            ),
            const SizedBox(height: 32),
            Text('Pending Requests', style: TextStyle(color: textSecondaryColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            _buildPendingRequest(
              context,
              "AC Servicing",
              "Rs. 2,000",
              "Gulberg III, Lahore",
              "15 mins ago",
              "https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=600&auto=format&fit=crop",
              isDark,
              surfaceColor,
              accentColor,
              textColor,
              hintTextColor,
              borderColor,
            ),
            const SizedBox(height: 16),
            _buildPendingRequest(
              context,
              "Electrical Wiring",
              "Rs. 3,500",
              "DHA Phase 5, Lahore",
              "32 mins ago",
              "https://images.unsplash.com/photo-1526778548025-fa2f459cd5c1?q=80&w=600&auto=format&fit=crop",
              isDark,
              surfaceColor,
              accentColor,
              textColor,
              hintTextColor,
              borderColor,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const ProviderBottomNav(currentIndex: 1),
    );
  }

  Widget _buildActiveJobCard(
    BuildContext context,
    WidgetRef ref,
    String jobTitle,
    String price,
    String customerName,
    String bookingId,
    bool isDark,
    Color backgroundColor,
    Color surfaceColor,
    Color accentColor,
    Color textColor,
    Color hintTextColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.build_circle_outlined, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(jobTitle, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                        ),
                        Text(price, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: hintTextColor, size: 14),
                        const SizedBox(width: 4),
                        Text(customerName, style: TextStyle(color: hintTextColor, fontSize: 12)),
                        const Spacer(),
                        Text('In Progress', style: TextStyle(color: hintTextColor, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:+923001234567')),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/provider_job_diagnosis'),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: isDark ? _kDarkBackgroundColor : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Cancelling booking... Re-routing customer to next top pro.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                await ref.read(bookingProvider.notifier).cancelBookingByProvider(bookingId);
              },
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.white),
              label: const Text('Cancel Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequest(
    BuildContext context,
    String title,
    String fare,
    String location,
    String time,
    String mapUrl,
    bool isDark,
    Color surfaceColor,
    Color accentColor,
    Color textColor,
    Color hintTextColor,
    Color borderColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                Image.network(mapUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.1), surfaceColor],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: Icon(Icons.location_on, color: accentColor, size: 32),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(fare, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: hintTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(location, style: TextStyle(color: hintTextColor, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, color: hintTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(time, style: TextStyle(color: hintTextColor, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined.')));
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: hintTextColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request accepted! Starting job...')));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor.withOpacity(0.1),
                          foregroundColor: accentColor,
                          elevation: 0,
                          side: BorderSide(color: accentColor, width: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
