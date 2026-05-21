import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/booking_provider.dart';
import '../providers/locale_provider.dart';
import '../models/provider_model.dart';
import '../widgets/customer_app_bar.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/customer_drawer.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> with SingleTickerProviderStateMixin {
  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentGreen = Color(0xFF4ADE80);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);

  static const Color _kLightBackgroundColor = Color(0xFFF8FAFC);
  static const Color _kLightSurfaceColor = Colors.white;
  static const Color _kLightAccentGreen = Color(0xFF0D9488);
  static const Color _kLightAccentCyan = Color(0xFF4F46E5);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _bookingSubscription;
  bool _showingBanner = false;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isScheduled = false;
  bool _isReminderSent = false;
  bool _isEnRoute = false;
  Timer? _simTimer1;
  Timer? _simTimer2;

  bool _isScheduledBooking(String timePref) {
    final clean = timePref.toLowerCase().trim();
    if (clean == 'now' ||
        clean == 'right now' ||
        clean == 'urgent' ||
        clean == 'urgently' ||
        clean == 'immediately' ||
        clean.contains('15 min') ||
        clean.contains('after 15') ||
        clean == '15 minutes') {
      return false;
    }
    final hasDigits = RegExp(r'\d').hasMatch(clean);
    if (hasDigits ||
        clean.contains('tomorrow') ||
        clean.contains('schedule') ||
        clean.contains('later') ||
        clean.contains('am') ||
        clean.contains('pm') ||
        clean.contains('morning') ||
        clean.contains('evening') ||
        clean.contains('afternoon')) {
      return true;
    }
    return false;
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
  }

  void _triggerNotification(String title, String body, int id) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'haazir_booking_channel',
      'Booking Notifications',
      channelDescription: 'Notifications for successful bookings',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void _checkScheduledSimulation() async {
    await _initLocalNotifications();
    
    final bookingState = ref.read(bookingProvider);
    final result = bookingState.result;
    if (result == null) return;

    final timePref = result.request.timePreference;
    if (_isScheduledBooking(timePref)) {
      setState(() {
        _isScheduled = true;
        _isEnRoute = false;
        _isReminderSent = false;
      });

      _simTimer1?.cancel();
      _simTimer2?.cancel();

      final providerName = result.topProvider.name;

      // Timer 1: 10s simulation -> triggers 10 min reminder
      _simTimer1 = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        _triggerNotification(
          '🔔 Haazir Reminder',
          'Your provider $providerName is scheduled to arrive at $timePref.',
          101,
        );
        setState(() {
          _isReminderSent = true;
        });
      });

      // Timer 2: 20s simulation -> triggers 2 min arrival status "is on his"
      _simTimer2 = Timer(const Duration(seconds: 20), () {
        if (!mounted) return;
        _triggerNotification(
          '📍 Haazir Tracker',
          '$providerName is on his way.',
          102,
        );
        setState(() {
          _isEnRoute = true;
        });
      });
    } else {
      setState(() {
        _isScheduled = false;
        _isEnRoute = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupBookingListener();
      _checkScheduledSimulation();
    });
  }

  void _setupBookingListener() {
    _bookingSubscription?.cancel();

    final isMock = ref.read(localeProvider).isMockMode;
    if (isMock) return;

    final bookingState = ref.read(bookingProvider);
    final bookingId = bookingState.result?.booking.bookingId;
    if (bookingId == null) return;

    _bookingSubscription = FirebaseFirestore.instance
        .collection('Bookings')
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      if (status == 'cancelled') {
        _handleProviderCancellation();
      }
    });
  }

  void _handleProviderCancellation() async {
    if (_showingBanner) return;
    setState(() {
      _showingBanner = true;
    });

    await ref.read(bookingProvider.notifier).triggerConciergeReRouting();

    _setupBookingListener();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 6),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade400, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Haazir Concierge Auto-Assignment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your previous provider was busy. Haazir Concierge has automatically assigned the next best professional!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      setState(() {
        _showingBanner = false;
      });
    }
  }

  @override
  void dispose() {
    _simTimer1?.cancel();
    _simTimer2?.cancel();
    _pulseController.dispose();
    _bookingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch status changes for auto-concierge re-routing in mock mode
    ref.listen<BookingState>(bookingProvider, (previous, next) {
      final isMock = ref.read(localeProvider).isMockMode;
      if (isMock) {
        final prevStatus = previous?.result?.booking.status;
        final nextStatus = next.result?.booking.status;
        if (nextStatus == 'cancelled' && prevStatus != 'cancelled') {
          _handleProviderCancellation();
        }
      }
    });

    final isDark = ref.watch(localeProvider).isDarkMode;
    final bookingState = ref.watch(bookingProvider);
    final result = bookingState.result;

    if (result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bookedProvider = result.topProvider;
    final otherPros = result.rankedProviders.where((p) => p.id != bookedProvider.id).take(3).toList();

    final backgroundColor = isDark ? _kDarkBackgroundColor : _kLightBackgroundColor;
    final surfaceColor = isDark ? _kDarkSurfaceColor : _kLightSurfaceColor;
    final accentGreen = isDark ? _kDarkAccentGreen : _kLightAccentGreen;
    final accentCyan = isDark ? _kDarkAccentCyan : _kLightAccentCyan;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final textSubtitleColor = isDark ? Colors.white30 : const Color(0xFF94A3B8);
    final borderSideColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomerAppBar(),
      drawer: const CustomerDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booked Section Header
              Row(
                children: [
                  Icon(Icons.star, color: accentCyan, size: 20),
                  const SizedBox(width: 8),
                  Text('Booked', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentGreen, width: 0.5),
                    ),
                    child: Text('CERTIFIED', style: TextStyle(color: accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Booked Card
              _buildBookedCard(
                context,
                bookedProvider,
                result.booking.priceEstimate,
                isDark,
                surfaceColor,
                textColor,
                textSecondaryColor,
                textSubtitleColor,
                borderSideColor,
                accentGreen,
                accentCyan,
              ),

              const SizedBox(height: 32),
              Text(
                'OTHER TOP PROS',
                style: TextStyle(color: textSecondaryColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 16),

              // Other Pros List
              ...otherPros.map((pro) => _buildOtherProCard(
                    context,
                    ref,
                    pro,
                    isDark,
                    surfaceColor,
                    textColor,
                    textSecondaryColor,
                    textSubtitleColor,
                    borderSideColor,
                    accentGreen,
                    accentCyan,
                  )),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 0),
    );
  }

  Widget _buildBookedCard(
    BuildContext context,
    ProviderModel pro,
    String fare,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color textSubtitleColor,
    Color borderSideColor,
    Color accentGreen,
    Color accentCyan,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderSideColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scheduled Booking Banner/Status
          if (_isScheduled) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: _isEnRoute 
                    ? accentGreen.withOpacity(0.12)
                    : Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isEnRoute 
                      ? accentGreen.withOpacity(0.4)
                      : Colors.amber.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEnRoute ? Icons.directions_car : Icons.schedule,
                    color: _isEnRoute ? accentGreen : Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEnRoute
                          ? "${pro.name} is on his way"
                          : "Provider will come at ${ref.watch(bookingProvider).result?.request.timePreference ?? 'scheduled time'} in morning",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentGreen.withValues(alpha: 0.5), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: pro.profileImageUrl != null
                          ? Image.network(pro.profileImageUrl!, width: 70, height: 70, fit: BoxFit.cover)
                          : Image.network('https://i.pravatar.cc/150?u=${pro.id}', width: 70, height: 70, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: accentGreen, shape: BoxShape.circle),
                      child: Icon(Icons.check, color: isDark ? _kDarkBackgroundColor : Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pro.name, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Certified ${pro.category} • ${pro.rating}★',
                      style: TextStyle(color: textSecondaryColor, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '127 jobs completed in Islamabad',
                      style: TextStyle(color: textSubtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildBadge(Icons.verified_user_outlined, 'Verified ID', accentCyan, isDark),
              const SizedBox(width: 8),
              _buildBadge(Icons.location_on_outlined, '9 min away', accentCyan, isDark),
              const SizedBox(width: 8),
              _buildBadge(Icons.workspace_premium_outlined, 'Pro', accentCyan, isDark),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Expert in leak detection and bathroom fittings. 10+ years experience providing premium plumbing solutions in Islamabad\'s F and G sectors.',
            style: TextStyle(color: textSecondaryColor, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTIMATED FARE',
                    style: TextStyle(color: textSubtitleColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fare.contains('Rs.') ? fare : 'Rs. 412',
                    style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      'Best Value',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.unfold_more, color: textSecondaryColor, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // ── Live Track Provider Button ──
          if (_isScheduled && !_isEnRoute)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live tracking will unlock 2 minutes before the scheduled arrival!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  border: Border.all(color: borderSideColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_outline, color: textSubtitleColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tracking unlocks 2 mins before arrival',
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: () => context.push('/nearby'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D1FF), Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D1FF).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Live Track Provider',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color accentCyan, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentCyan, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherProCard(
    BuildContext context,
    WidgetRef ref,
    ProviderModel pro,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color textSubtitleColor,
    Color borderSideColor,
    Color accentGreen,
    Color accentCyan,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSideColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: pro.profileImageUrl != null
                ? Image.network(pro.profileImageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                : Image.network('https://i.pravatar.cc/100?u=${pro.id}', width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pro.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${pro.rating}★',
                      style: TextStyle(color: accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      ' • 15 min away',
                      style: TextStyle(color: textSubtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs. 450', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              Text('PER HOUR', style: TextStyle(color: textSubtitleColor, fontSize: 8)),
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: () {
                    // Logic to re-book this provider
                    final bookingState = ref.read(bookingProvider);
                    if (bookingState.result != null) {
                       final oldBooking = bookingState.result!.booking;
                       ref.read(bookingProvider.notifier).addToHistory(oldBooking.copyWith(status: 'cancelled'));
                       
                       // Simulate new booking
                       final newBooking = oldBooking.copyWith(
                         bookingId: 'BK-${DateTime.now().millisecondsSinceEpoch}',
                         providerId: pro.id,
                         providerName: pro.name,
                         status: 'active',
                       );
                       
                       // Update the result state to reflect new top choice
                       final newResult = bookingState.result!.copyWith(
                         topProvider: pro,
                         booking: newBooking,
                       );
                       
                       ref.read(bookingProvider.notifier).updateResult(newResult);
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hired ${pro.name}! New booking confirmed.')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: isDark ? _kDarkBackgroundColor : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('HIRE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
