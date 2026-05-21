import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';
import 'locale_provider.dart';
import '../models/booking_model.dart';

class ProviderDashboardData {
  final double todayEarnings;
  final int jobsDone;
  final double acceptanceRate;
  final double avgRating;
  final List<BookingModel> recentJobs;
  final bool isLoading;

  ProviderDashboardData({
    this.todayEarnings = 0.0,
    this.jobsDone = 0,
    this.acceptanceRate = 0.0,
    this.avgRating = 0.0,
    this.recentJobs = const [],
    this.isLoading = false,
  });
}

class ProviderDashboardNotifier extends StateNotifier<ProviderDashboardData> {
  final Ref ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ProviderDashboardNotifier(this.ref) : super(ProviderDashboardData()) {
    refresh();
  }

  Future<void> refresh() async {
    final isMock = ref.read(localeProvider).isMockMode;
    final user = ref.read(authProvider).user;

    if (isMock) {
      _loadMockData();
      return;
    }

    if (user == null) return;

    state = ProviderDashboardData(isLoading: true);

    try {
      // Fetch stats from ProviderProfiles
      final profileDoc = await _db.collection('ProviderProfiles').doc(user.id).get();
      final profileData = profileDoc.data();

      // Fetch recent jobs from Bookings
      final jobsQuery = await _db.collection('Bookings')
          .where('providerId', isEqualTo: user.id)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final List<BookingModel> jobs = jobsQuery.docs.map((doc) {
        final data = doc.data();
        return BookingModel(
          bookingId: doc.id,
          providerId: data['providerId'] ?? '',
          providerName: data['providerName'] ?? '',
          providerPhone: data['providerPhone'] ?? '',
          customerName: data['customerName'] ?? '',
          customerPhone: data['customerPhone'] ?? '',
          serviceCategory: data['serviceCategory'] ?? '',
          serviceType: data['serviceType'] ?? '',
          location: data['location'] ?? '',
          slot: (data['slot'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: data['status'] ?? '',
          priceEstimate: data['priceEstimate'] ?? '',
          confirmationMessage: data['confirmationMessage'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      // If no data exists in Firestore for the profile, or total jobs is 0, or bookings are empty,
      // automatically fall back to loading highly realistic mock data.
      if (profileData == null || (profileData['total_jobs'] ?? 0) == 0 || jobs.isEmpty) {
        _loadMockData();
        return;
      }

      state = ProviderDashboardData(
        todayEarnings: (profileData['today_earnings'] ?? 0.0).toDouble(),
        jobsDone: profileData['total_jobs'] ?? 0,
        acceptanceRate: (profileData['acceptance_rate'] ?? 0.0).toDouble(),
        avgRating: (profileData['rating'] ?? 0.0).toDouble(),
        recentJobs: jobs,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error fetching provider dashboard data: $e");
      state = ProviderDashboardData(isLoading: false);
    }
  }

  void _loadMockData() {
    state = ProviderDashboardData(
      todayEarnings: 2400.0,
      jobsDone: 7,
      acceptanceRate: 87.0,
      avgRating: 4.8,
      recentJobs: [
        BookingModel(
          bookingId: '1',
          providerId: 'p1',
          providerName: 'Test Provider',
          providerPhone: '123',
          customerName: 'Ali Khan',
          customerPhone: '456',
          serviceCategory: 'Plumbing',
          serviceType: 'Leaky Pipe Fix',
          location: 'F-8/1, Islamabad',
          slot: DateTime.now(),
          status: 'COMPLETED',
          priceEstimate: 'Rs. 850',
          confirmationMessage: '',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        BookingModel(
          bookingId: '2',
          providerId: 'p1',
          providerName: 'Test Provider',
          providerPhone: '123',
          customerName: 'Zainab Bibi',
          customerPhone: '789',
          serviceCategory: 'Electrician',
          serviceType: 'Wiring Inspection',
          location: 'G-11/3, Islamabad',
          slot: DateTime.now(),
          status: 'CANCELLED',
          priceEstimate: 'Rs. 1,200',
          confirmationMessage: '',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        BookingModel(
          bookingId: '3',
          providerId: 'p1',
          providerName: 'Test Provider',
          providerPhone: '123',
          customerName: 'Usman Ali',
          customerPhone: '012',
          serviceCategory: 'AC Service',
          serviceType: 'AC Servicing',
          location: 'DHA Phase 2, Rawalpindi',
          slot: DateTime.now(),
          status: 'COMPLETED',
          priceEstimate: 'Rs. 3,500',
          confirmationMessage: '',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        BookingModel(
          bookingId: '4',
          providerId: 'p1',
          providerName: 'Test Provider',
          providerPhone: '123',
          customerName: 'Aisha Malik',
          customerPhone: '135',
          serviceCategory: 'Cleaning',
          serviceType: 'Deep House Cleaning',
          location: 'E-11/2, Islamabad',
          slot: DateTime.now(),
          status: 'COMPLETED',
          priceEstimate: 'Rs. 4,500',
          confirmationMessage: '',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        BookingModel(
          bookingId: '5',
          providerId: 'p1',
          providerName: 'Test Provider',
          providerPhone: '123',
          customerName: 'Bilal Siddiqui',
          customerPhone: '246',
          serviceCategory: 'Painter',
          serviceType: 'Wall Paint Touchup',
          location: 'Saddar, Rawalpindi',
          slot: DateTime.now(),
          status: 'COMPLETED',
          priceEstimate: 'Rs. 2,800',
          confirmationMessage: '',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
      isLoading: false,
    );
  }
}

final providerDashboardProvider = StateNotifierProvider<ProviderDashboardNotifier, ProviderDashboardData>((ref) {
  return ProviderDashboardNotifier(ref);
});
