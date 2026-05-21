import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/google_details_screen.dart';
import 'screens/home_screen.dart';
import 'screens/provider_dashboard.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/nearby_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/agent_processing_pipeline.dart';
import 'screens/provider_jobs_screen.dart';
import 'screens/provider_job_diagnosis_screen.dart';
import 'screens/provider_history_screen.dart';
import 'screens/provider_earnings_screen.dart';
import 'screens/provider_evaluation_screen.dart';
import 'screens/provider_profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/support_screen.dart';
import 'screens/support_chatbot.dart';
import 'screens/saved_addresses_screen.dart';
import 'providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthStateNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isInitialized = authState.isInitialized;
      if (!isInitialized) return null;

      final bool loggedIn = authState.isAuthenticated;
      final bool loggingIn = state.matchedLocation == '/login' || 
                           state.matchedLocation == '/signup' || 
                           state.matchedLocation == '/otp' ||
                           state.matchedLocation == '/google_details' ||
                           state.matchedLocation == '/';

      if (!loggedIn) {
        return loggingIn ? null : '/login';
      }

      // If logged in but on auth screens, move to correct dashboard
      if (loggingIn && state.matchedLocation != '/') {
        final role = authState.user?.role;
        return role == 'provider' ? '/provider_dashboard' : '/home';
      }

      // Role-based protection
      final role = authState.user?.role;
      if (role == 'provider' && state.matchedLocation == '/home') {
        return '/provider_dashboard';
      }
      if (role == 'customer' && state.matchedLocation == '/provider_dashboard') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      GoRoute(
        path: '/otp', 
        builder: (c, s) {
          final data = s.extra as Map<String, dynamic>;
          return OtpScreen(signupData: data);
        }
      ),
      GoRoute(
        path: '/google_details',
        builder: (c, s) {
          final data = s.extra as Map<String, dynamic>;
          return GoogleDetailsScreen(
            email: data['email'] as String,
            name: data['name'] as String?,
            role: data['role'] as String?,
          );
        }
      ),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
      GoRoute(path: '/nearby', builder: (c, s) => const NearbyScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/processing-pipeline', builder: (c, s) => const AgentProcessingPipeline()),
      GoRoute(path: '/provider_dashboard', builder: (c, s) => const ProviderDashboard()),
      GoRoute(path: '/provider_jobs', builder: (c, s) => const ProviderJobsScreen()),
      GoRoute(path: '/provider_job_diagnosis', builder: (c, s) => const ProviderJobDiagnosisScreen()),
      GoRoute(path: '/provider_history', builder: (c, s) => const ProviderHistoryScreen()),
      GoRoute(path: '/provider_earnings', builder: (c, s) => const ProviderEarningsScreen()),
      GoRoute(path: '/provider_evaluation', builder: (c, s) => const ProviderEvaluationScreen()),
      GoRoute(path: '/provider_profile', builder: (c, s) => const ProviderProfileScreen()),
      GoRoute(path: '/edit_profile', builder: (c, s) => const EditProfileScreen()),
      GoRoute(path: '/saved_addresses', builder: (c, s) => const SavedAddressesScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/support', builder: (c, s) => const SupportScreen()),
      GoRoute(path: '/chatbot', builder: (c, s) => const SupportChatbot()),
      GoRoute(path: '/results', builder: (c, s) => const ResultsScreen()),
    ],
  );
});

// Helper to make router listen to auth changes
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(ProviderRef ref) {
    ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }
}
