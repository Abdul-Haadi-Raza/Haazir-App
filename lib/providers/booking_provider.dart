import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide PipelineResult;
import 'package:flutter/foundation.dart';
import 'auth_provider.dart';
import 'locale_provider.dart';
import '../agents/orchestrator.dart';
import '../agents/concierge_agent.dart';
import '../models/agent_trace.dart';
import '../models/booking_model.dart';
import '../models/provider_model.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';

class BookingState {
  final String userQuery;
  final List<AgentTrace> traces;
  final int currentAgentIndex;
  final PipelineResult? result;
  final bool isLoading;
  final String? error;
  final List<BookingModel> history;

  const BookingState({
    this.userQuery = '',
    this.traces = const [],
    this.currentAgentIndex = -1,
    this.result,
    this.isLoading = false,
    this.error,
    this.history = const [],
  });

  BookingState copyWith({
    String? userQuery,
    List<AgentTrace>? traces,
    int? currentAgentIndex,
    PipelineResult? result,
    bool? isLoading,
    String? error,
    List<BookingModel>? history,
  }) {
    return BookingState(
      userQuery: userQuery ?? this.userQuery,
      traces: traces ?? this.traces,
      currentAgentIndex: currentAgentIndex ?? this.currentAgentIndex,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      history: history ?? this.history,
    );
  }

  bool get isDone => currentAgentIndex >= 5;
}

class BookingNotifier extends StateNotifier<BookingState> {
  final Ref ref;
  BookingNotifier(this.ref) : super(const BookingState());

  Future<void> runPipeline(String query, UserModel? user) async {
    state = BookingState(
      userQuery: query,
      isLoading: true,
      currentAgentIndex: 0,
      traces: [],
      history: state.history,
    );

    try {
      final userId = user?.id ?? 'anonymous';
      
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': query,
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Server Error: \${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final status = data['status'];
      
      List<AgentTrace> traces = [];
      
      if (status == 'clarification_needed') {
        traces.add(AgentTrace(
          agentName: 'ConversationalAgent',
          role: 'Understanding your request',
          icon: 'translate',
          input: query,
          output: 'Missing details detected',
          reasoning: data['agent_logs'],
          durationLabel: '500ms',
        ));
        state = state.copyWith(
          traces: traces,
          currentAgentIndex: 1,
          isLoading: false,
          error: data['reply'],
        );
        return;
      }

      if (status == 'failed' || status == 'error') {
         throw Exception(data['reply'] ?? data['message']);
      }

      final logs = data['agent_logs'] as List<dynamic>? ?? [];
      
      for (int i = 0; i < logs.length; i++) {
        await Future.delayed(const Duration(milliseconds: 800));
        traces = [...traces, AgentTrace(
          agentName: 'Agent \${i+1}',
          role: 'Processing step',
          icon: 'auto_awesome',
          input: 'Pipeline step',
          output: 'Task completed',
          reasoning: logs[i].toString(),
          durationLabel: '800ms',
        )];
        state = state.copyWith(traces: traces, currentAgentIndex: i + 1);
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final bookingData = data['booking'];
      final mockProvider = ProviderModel(
        id: bookingData['provider_id'] ?? '123',
        name: 'Assigned Provider',
        category: bookingData['service'] ?? 'Unknown',
        area: bookingData['location'] ?? 'Unknown',
        latitude: 0.0,
        longitude: 0.0,
        rating: 4.5,
        totalReviews: 10,
        priceRange: 'Rs. 500+',
        availability: const {},
        phone: '1234567890',
        verified: true,
        profileImageUrl: null,
      );
      
      final result = PipelineResult(
        request: ServiceRequest(
          originalInput: query,
          detectedLanguage: 'english',
          serviceType: bookingData['service'] ?? 'Unknown',
          serviceCategory: bookingData['service'] ?? 'Unknown',
          location: bookingData['location'] ?? 'Unknown',
          timePreference: bookingData['time'] ?? 'Now',
          urgency: 'normal',
          reasoning: bookingData['repair_details'] ?? '',
        ),
        providers: [mockProvider],
        rankedProviders: [mockProvider],
        topProvider: mockProvider,
        matchReasoning: 'Matchmaker found closest provider.',
        booking: BookingModel(
          bookingId: bookingData['booking_id'] ?? '123',
          providerId: bookingData['provider_id'] ?? '123',
          providerName: 'Assigned Provider',
          providerPhone: '1234567890',
          customerName: user?.name ?? 'Customer',
          customerPhone: user?.phone ?? '',
          serviceCategory: bookingData['service'] ?? 'Unknown',
          serviceType: bookingData['service'] ?? 'Unknown',
          location: bookingData['location'] ?? 'Unknown',
          slot: DateTime.now(),
          status: 'pending',
          priceEstimate: data['reply'] ?? '',
          confirmationMessage: data['reply'] ?? '',
          createdAt: DateTime.now(),
        ),
        schedule: const ConciergeSchedule(followUpActions: []),
      );

      state = state.copyWith(
        result: result,
        currentAgentIndex: 5,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Connection closed before full header was received')) {
        errorMessage = "Backend connection lost. Try running the backend on 0.0.0.0:8000";
      } else if (errorMessage.contains('TimeoutException')) {
        errorMessage = "Request timed out. The AI is taking too long to respond.";
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage.replaceAll('Exception: ', ''),
        currentAgentIndex: -1,
      );
    }
  }

  void setBookingFromResult(Map<String, dynamic> data, String query, UserModel? user) {
    final bookingData = data['booking'] ?? {};
    final providerData = data['provider'] ?? {};
    final allMatchesData = data['all_matches'] as List<dynamic>? ?? [providerData];
    
    final topProvider = ProviderModel(
      id: providerData['uid'] ?? bookingData['provider_id'] ?? '123',
      name: providerData['name'] ?? 'Assigned Provider',
      category: providerData['category'] ?? bookingData['service'] ?? 'Unknown',
      area: providerData['area'] ?? bookingData['location'] ?? 'Unknown',
      latitude: (providerData['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (providerData['longitude'] as num?)?.toDouble() ?? 0.0,
      rating: (providerData['rating'] as num?)?.toDouble() ?? 4.5,
      totalReviews: providerData['total_jobs'] as int? ?? 10,
      priceRange: providerData['estimated_price'] ?? 'Rs. 500+',
      availability: const {},
      phone: providerData['phone'] ?? '1234567890',
      verified: (providerData['is_verified'] as bool?) ?? (providerData['verified'] as bool?) ?? true,
      profileImageUrl: providerData['profileImageUrl'],
    );

    final List<ProviderModel> rankedProviders = allMatchesData.map((p) {
      return ProviderModel(
        id: p['uid'] ?? '123',
        name: p['name'] ?? 'Provider',
        category: p['category'] ?? bookingData['service'] ?? 'Unknown',
        area: p['area'] ?? bookingData['location'] ?? 'Unknown',
        latitude: (p['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (p['longitude'] as num?)?.toDouble() ?? 0.0,
        rating: (p['rating'] as num?)?.toDouble() ?? 4.5,
        totalReviews: p['total_jobs'] as int? ?? 10,
        priceRange: p['estimated_price'] ?? 'Rs. 500+',
        availability: const {},
        phone: p['phone'] ?? '1234567890',
        verified: (p['is_verified'] as bool?) ?? (p['verified'] as bool?) ?? true,
        profileImageUrl: p['profileImageUrl'],
      );
    }).toList();

    final logs = data['agent_logs'] as List<dynamic>? ?? [];
    List<AgentTrace> traces = [];
    for (int i = 0; i < logs.length; i++) {
      traces.add(AgentTrace(
        agentName: i == 0 ? 'ConversationalAgent' : (i == 1 ? 'MatchmakerAgent' : (i == 2 ? 'BookerAgent' : 'FollowUpAgent')),
        role: 'Processing step',
        icon: 'auto_awesome',
        input: 'Pipeline step',
        output: 'Task completed',
        reasoning: logs[i].toString(),
        durationLabel: '800ms',
      ));
    }

    final result = PipelineResult(
      request: ServiceRequest(
        originalInput: query,
        detectedLanguage: 'english',
        serviceType: bookingData['service'] ?? 'Unknown',
        serviceCategory: bookingData['service'] ?? 'Unknown',
        location: bookingData['location'] ?? 'Unknown',
        timePreference: bookingData['time'] ?? 'Now',
        urgency: 'normal',
        reasoning: bookingData['repair_details'] ?? '',
      ),
      providers: rankedProviders,
      rankedProviders: rankedProviders,
      topProvider: topProvider,
      matchReasoning: 'Matchmaker found closest provider.',
      booking: BookingModel(
        bookingId: bookingData['booking_id'] ?? '123',
        providerId: bookingData['provider_id'] ?? '123',
        providerName: topProvider.name,
        providerPhone: topProvider.phone,
        customerName: user?.name ?? 'Customer',
        customerPhone: user?.phone ?? '',
        serviceCategory: bookingData['service'] ?? 'Unknown',
        serviceType: bookingData['service'] ?? 'Unknown',
        location: bookingData['location'] ?? 'Unknown',
        slot: DateTime.now(),
        status: 'pending',
        priceEstimate: topProvider.priceRange,
        confirmationMessage: data['reply'] ?? '',
        createdAt: DateTime.now(),
      ),
      schedule: const ConciergeSchedule(followUpActions: []),
    );

    state = state.copyWith(
      userQuery: query,
      traces: traces,
      currentAgentIndex: 5,
      result: result,
      isLoading: false,
      error: null,
    );
  }

  void updateResult(PipelineResult newResult) {
    state = state.copyWith(result: newResult);
  }

  void addToHistory(BookingModel booking) {
    state = state.copyWith(history: [booking, ...state.history]);
  }

  Map<String, dynamic> bookingToMap(BookingModel booking) {
    return {
      'booking_id': booking.bookingId,
      'provider_id': booking.providerId,
      'provider_name': booking.providerName,
      'provider_phone': booking.providerPhone,
      'customer_name': booking.customerName,
      'customer_phone': booking.customerPhone,
      'service': booking.serviceCategory,
      'location': booking.location,
      'time': booking.slot.toIso8601String(),
      'status': booking.status,
      'price_estimate': booking.priceEstimate,
      'confirmation_message': booking.confirmationMessage,
      'created_at': booking.createdAt.toIso8601String(),
    };
  }

  Future<void> saveBookingToFirestore(BookingModel booking) async {
    final isMock = ref.read(localeProvider).isMockMode;
    final user = ref.read(authProvider).user;

    addToHistory(booking);

    if (isMock || user == null) {
      debugPrint("Mock Mode: Saved booking locally.");
      return;
    }

    try {
      final bookingData = bookingToMap(booking);
      
      await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(booking.bookingId)
          .set(bookingData);

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.id)
          .collection('Bookings')
          .doc(booking.bookingId)
          .set(bookingData);

      debugPrint("Successfully saved booking ${booking.bookingId} to Firestore.");
    } catch (e) {
      debugPrint("Error saving booking to Firestore: $e");
    }
  }

  Future<void> cancelBookingByProvider(String bookingId) async {
    final isMock = ref.read(localeProvider).isMockMode;
    
    final currentResult = state.result;
    if (currentResult != null && currentResult.booking.bookingId == bookingId) {
      state = state.copyWith(
        result: currentResult.copyWith(
          booking: currentResult.booking.copyWith(status: 'cancelled'),
        ),
      );
    }
    
    state = state.copyWith(
      history: state.history.map((b) => b.bookingId == bookingId ? b.copyWith(status: 'cancelled') : b).toList(),
    );

    if (isMock) {
      debugPrint("Mock Mode: Cancelled booking $bookingId locally.");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('Bookings')
          .doc(bookingId)
          .update({'status': 'cancelled'});

      final user = ref.read(authProvider).user;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.id)
            .collection('Bookings')
            .doc(bookingId)
            .update({'status': 'cancelled'});
      }
      
      debugPrint("Successfully updated booking status to 'cancelled' in Firestore.");
    } catch (e) {
      debugPrint("Error cancelling booking in Firestore: $e");
    }
  }

  Future<void> triggerConciergeReRouting() async {
    final currentResult = state.result;
    if (currentResult == null) return;

    final user = ref.read(authProvider).user;
    final lastProviderId = currentResult.topProvider.id;
    final remainingPool = currentResult.rankedProviders.where((p) => p.id != lastProviderId).toList();

    if (remainingPool.isEmpty) {
      debugPrint("No other providers available in the candidate pool.");
      return;
    }

    final newTopProvider = remainingPool.first;
    final newBookingId = 'BK-${DateTime.now().millisecondsSinceEpoch}';
    final newBooking = BookingModel(
      bookingId: newBookingId,
      providerId: newTopProvider.id,
      providerName: newTopProvider.name,
      providerPhone: newTopProvider.phone,
      customerName: user?.name ?? 'Customer',
      customerPhone: user?.phone ?? '',
      serviceCategory: currentResult.booking.serviceCategory,
      serviceType: currentResult.booking.serviceType,
      location: currentResult.booking.location,
      slot: DateTime.now(),
      status: 'active',
      priceEstimate: newTopProvider.priceRange,
      confirmationMessage: 'Assigned automatically by Haazir Concierge',
      createdAt: DateTime.now(),
    );

    final newResult = PipelineResult(
      request: currentResult.request,
      providers: remainingPool,
      rankedProviders: remainingPool,
      topProvider: newTopProvider,
      matchReasoning: 'Haazir Concierge automatically re-routed and selected the next best pro.',
      booking: newBooking,
      schedule: currentResult.schedule,
    );

    final oldCancelledBooking = currentResult.booking.copyWith(status: 'cancelled');
    addToHistory(oldCancelledBooking);

    state = state.copyWith(result: newResult);

    await saveBookingToFirestore(newBooking);
  }

  void reset() {
    state = BookingState(history: state.history);
  }

  Future<void> fetchHistory() async {
    final isMock = ref.read(localeProvider).isMockMode;
    final user = ref.read(authProvider).user;

    if (isMock || user == null) {
      _loadMockHistory();
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.id)
          .collection('Bookings')
          .orderBy('created_at', descending: true)
          .get();

      final List<BookingModel> bookings = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return BookingModel(
          bookingId: doc.id,
          providerId: data['provider_id'] ?? '',
          providerName: data['provider_name'] ?? data['provider']?['name'] ?? 'Assigned Provider',
          providerPhone: data['provider_phone'] ?? data['provider']?['phone'] ?? '',
          customerName: data['customer_name'] ?? user.name,
          customerPhone: data['customer_phone'] ?? user.phone ?? '',
          serviceCategory: data['service'] ?? 'Unknown',
          serviceType: data['service'] ?? 'Unknown',
          location: data['location'] ?? 'Unknown',
          slot: data['time'] != null ? DateTime.tryParse(data['time']) ?? DateTime.now() : DateTime.now(),
          status: data['status'] ?? 'pending',
          priceEstimate: data['price_estimate'] ?? data['priceEstimate'] ?? '',
          confirmationMessage: data['confirmation_message'] ?? data['confirmationMessage'] ?? '',
          createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at']) ?? DateTime.now() : DateTime.now(),
        );
      }).toList();

      state = state.copyWith(history: bookings);
    } catch (e) {
      debugPrint("Error fetching history: $e");
      _loadMockHistory();
    }
  }

  void _loadMockHistory() {
    state = state.copyWith(
      history: [
        BookingModel(
          bookingId: '1',
          providerId: 'p1',
          providerName: 'Muhammad Arshad',
          providerPhone: '03001234567',
          customerName: 'Customer',
          customerPhone: '',
          serviceCategory: 'plumber',
          serviceType: 'plumber',
          location: 'F-8/3, Islamabad',
          slot: DateTime.now().subtract(const Duration(days: 1)),
          status: 'completed',
          priceEstimate: 'Rs. 600',
          confirmationMessage: 'Done',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        BookingModel(
          bookingId: '2',
          providerId: 'p2',
          providerName: 'Kamran Ali',
          providerPhone: '03007654321',
          customerName: 'Customer',
          customerPhone: '',
          serviceCategory: 'electrician',
          serviceType: 'electrician',
          location: 'G-9/2, Islamabad',
          slot: DateTime.now().subtract(const Duration(days: 3)),
          status: 'cancelled',
          priceEstimate: 'Rs. 450',
          confirmationMessage: 'Cancelled by user',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    );
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>(
  (ref) => BookingNotifier(ref),
);
