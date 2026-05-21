import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/booking_provider.dart';
import '../providers/locale_provider.dart';
import '../models/booking_model.dart';
import '../widgets/customer_app_bar.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/customer_drawer.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkPrimaryPurple = Color(0xFFBDB2FF);
  static const Color _kDarkHintTextColor = Color(0xFF6B7280);

  static const Color _kLightBackgroundColor = Color(0xFFF8FAFC);
  static const Color _kLightSurfaceColor = Colors.white;
  static const Color _kLightPrimaryIndigo = Color(0xFF4F46E5);
  static const Color _kLightHintTextColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingProvider.notifier).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final history = ref.watch(bookingProvider).history;

    final backgroundColor = isDark ? _kDarkBackgroundColor : _kLightBackgroundColor;
    final surfaceColor = isDark ? _kDarkSurfaceColor : _kLightSurfaceColor;
    final accentColor = isDark ? _kDarkPrimaryPurple : _kLightPrimaryIndigo;
    final hintTextColor = isDark ? _kDarkHintTextColor : _kLightHintTextColor;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderSideColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomerAppBar(),
      drawer: const CustomerDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'My History',
                style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: accentColor,
              labelColor: accentColor,
              unselectedLabelColor: hintTextColor,
              tabs: const [
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingList(
                    history.where((b) => b.status == 'active' || b.status == 'pending').toList(),
                    isDark,
                    surfaceColor,
                    textColor,
                    hintTextColor,
                    borderSideColor,
                    accentColor,
                  ),
                  _buildBookingList(
                    history.where((b) => b.status == 'completed').toList(),
                    isDark,
                    surfaceColor,
                    textColor,
                    hintTextColor,
                    borderSideColor,
                    accentColor,
                  ),
                  _buildBookingList(
                    history.where((b) => b.status == 'cancelled').toList(),
                    isDark,
                    surfaceColor,
                    textColor,
                    hintTextColor,
                    borderSideColor,
                    accentColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chatbot'),
        backgroundColor: accentColor,
        shape: const CircleBorder(),
        child: Icon(Icons.chat_bubble_outline, color: isDark ? _kDarkBackgroundColor : Colors.white),
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBookingList(
    List<BookingModel> bookings,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color hintTextColor,
    Color borderSideColor,
    Color accentColor,
  ) {
    if (bookings.isEmpty) {
      return Center(child: Text('No bookings found', style: TextStyle(color: hintTextColor)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        final statusColor = _getStatusColor(b.status, isDark, accentColor);
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSideColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getStatusIcon(b.status), color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.serviceCategory,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.providerName,
                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 13),
                    ),
                    Text(
                      b.location,
                      style: TextStyle(color: hintTextColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    b.priceEstimate,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    b.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status, bool isDark, Color accentColor) {
    switch (status) {
      case 'active':
      case 'pending':
        return accentColor;
      case 'completed':
        return isDark ? Colors.greenAccent : Colors.green;
      case 'cancelled':
        return isDark ? Colors.redAccent : Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
      case 'pending':
        return Icons.sync;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}
