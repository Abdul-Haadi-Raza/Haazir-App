import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/booking_provider.dart';
import '../providers/locale_provider.dart';

class AgentProcessingPipeline extends ConsumerStatefulWidget {
  const AgentProcessingPipeline({super.key});

  @override
  ConsumerState<AgentProcessingPipeline> createState() => _AgentProcessingPipeline();
}

class _AgentProcessingPipeline extends ConsumerState<AgentProcessingPipeline> with TickerProviderStateMixin {
  int _activeStep = 0; 
  int _revealedCount = 1;
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _rippleController;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final List<Map<String, dynamic>> _agents = [
    {
      'name': 'LINGUIST AGENT',
      'color': const Color(0xFF3B82F6),
      'icon': Icons.translate,
      'status': 'Intent parsed',
      'duration': 2000,
    },
    {
      'name': 'SCOUT AGENT',
      'color': const Color(0xFFF59E0B),
      'icon': Icons.explore_outlined,
      'status': 'Pros located',
      'duration': 2500,
    },
    {
      'name': 'Matchmaker',
      'color': const Color(0xFFEC4899),
      'icon': Icons.handshake_outlined,
      'status': 'Filtering by top ratings & availability...',
      'duration': 3500,
    },
    {
      'name': 'BOOKER AGENT',
      'color': const Color(0xFF10B981),
      'icon': Icons.calendar_today_outlined,
      'status': 'Booking confirmed',
      'duration': 2000,
    },
    {
      'name': 'CONCIERGE',
      'color': const Color(0xFF8B5CF6),
      'icon': Icons.notifications_active_outlined,
      'status': 'User notified',
      'duration': 1500,
    },
  ];

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _initializeNotifications();
    _startPipeline();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    // Explicit syntax for v17.0.0
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    // Request permissions for Android 13+
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> _showNotification() async {
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
    
    // Immediate confirmation notification
    await flutterLocalNotificationsPlugin.show(
      0,
      '✅ Booking Confirmed!',
      'Haazir has assigned a provider for your request. They are on their way!',
      platformChannelSpecifics,
    );

    // Schedule provider reminder (5 seconds for demo, simulates 10 min before)
    _scheduleDelayedNotification(
      id: 1,
      delay: const Duration(seconds: 5),
      title: '🔔 Haazir Reminder - Provider',
      body: 'You have a service job coming up! Time to head to the customer\'s location. Open Haazir for navigation.',
    );

    // Schedule customer reminder (10 seconds for demo, simulates provider en route)
    _scheduleDelayedNotification(
      id: 2,
      delay: const Duration(seconds: 10),
      title: '🔔 Haazir Tracker',
      body: 'Your service provider is 10 minutes away and traveling to your location! Track them live on the map.',
    );

    // Schedule provider arrival ETA notification (18 seconds for demo)
    _scheduleDelayedNotification(
      id: 3,
      delay: const Duration(seconds: 18),
      title: '📍 Provider Approaching',
      body: 'Your provider is just 2 minutes away! Please ensure access to the service area.',
    );
  }

  void _scheduleDelayedNotification({
    required int id,
    required Duration delay,
    required String title,
    required String body,
  }) {
    Future.delayed(delay, () async {
      if (!mounted) return;
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'haazir_reminder_channel',
        'Haazir Reminders',
        channelDescription: 'Scheduled reminders for bookings',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'reminder',
        styleInformation: BigTextStyleInformation(''),
      );
      const NotificationDetails details =
          NotificationDetails(android: androidDetails);
      
      await flutterLocalNotificationsPlugin.show(id, title, body, details);
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPipeline() async {
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      setState(() {
        _activeStep = i;
        _revealedCount = i + 1;
      });
      
      _scrollToActive();

      // At each step, provide a small haptic feedback
      HapticFeedback.lightImpact();

      await Future.delayed(Duration(milliseconds: _agents[i]['duration']));
      
      if (i == 4) {
        // Last step completed! Vibrate and show notification
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 500);
        }
        await _showNotification();
        
        // Save the booking to Firestore / History
        final bookingState = ref.read(bookingProvider);
        if (bookingState.result != null) {
          await ref.read(bookingProvider.notifier).saveBookingToFirestore(
            bookingState.result!.booking.copyWith(status: 'active')
          );
        }
        break;
      }
      
      // Small delay before showing next
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) context.pushReplacement('/results');
  }

  void _scrollToActive() {
    // Wait for the UI to build the new revealed item
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _activeStep * 180.0, // Approximate height of each node + connector
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecColor = isDark ? Colors.white70 : const Color(0xFF4B5563);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: textColor),
          onPressed: () {},
        ),
        title: Text('HAAZIR', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('اردو', style: TextStyle(color: textSecColor, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'AI Agents are analyzing your request.',
            style: TextStyle(color: textSecColor, fontSize: 16),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.2, // Start roughly in middle
                bottom: MediaQuery.of(context).size.height * 0.4,
              ),
              itemCount: _revealedCount,
              itemBuilder: (context, index) {
                return _buildNode(index, backgroundColor, textColor, textSecColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(int index, Color backgroundColor, Color textColor, Color textSecColor) {
    final agent = _agents[index];
    final isActive = _activeStep == index;
    final isCompleted = index < _activeStep;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulse Ripple Animation
            if (isActive)
              AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildRipple(1.0, agent['color']),
                      _buildRipple(0.6, agent['color']),
                      _buildRipple(0.2, agent['color']),
                    ],
                  );
                },
              ),
            // The Agent Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: isActive ? 100 : 60,
              height: isActive ? 100 : 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                border: Border.all(
                  color: agent['color'],
                  width: isActive ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: agent['color'].withOpacity(0.3),
                    blurRadius: isActive ? 20 : 10,
                    spreadRadius: isActive ? 5 : 2,
                  ),
                ],
              ),
              child: Icon(
                agent['icon'],
                color: agent['color'],
                size: isActive ? 40 : 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Agent Text
        Column(
          children: [
            Text(
              isActive && agent['name'] == 'Matchmaker' ? 'Matchmaker' : agent['name'].toUpperCase(),
              style: TextStyle(
                color: agent['color'],
                fontSize: isActive ? 24 : 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isCompleted ? 'Completed' : agent['status'],
              style: TextStyle(
                color: textSecColor,
                fontSize: isActive ? 16 : 12,
              ),
            ),
          ],
        ),
        // Connector line to next node
        if (index < _revealedCount - 1)
          Container(
            height: 80,
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  agent['color'],
                  _agents[index + 1]['color'],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRipple(double startDelay, Color color) {
    // Create an expanding ripple effect
    double progress = (_rippleController.value + startDelay) % 1.0;
    double opacity = 1.0 - progress;
    double size = 100 + (progress * 80);

    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }
}
