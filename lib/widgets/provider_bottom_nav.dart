import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';

class ProviderBottomNav extends ConsumerWidget {
  final int currentIndex;
  const ProviderBottomNav({super.key, required this.currentIndex});

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kInputBorderColor = Color(0xFF2E344A);
  static const Color _kHintTextColor = Color(0xFF6B7280);
  static const Color _kAccentCyan = Color(0xFF00D1FF);

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    
    switch (index) {
      case 0:
        context.go('/provider_dashboard');
        break;
      case 1:
        context.go('/provider_history');
        break;
      case 2:
        context.go('/provider_earnings');
        break;
      case 3:
        context.go('/provider_profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.read(localeProvider.notifier).translate;
    final isDark = ref.watch(localeProvider).isDarkMode;
    final backgroundColor = isDark ? _kBackgroundColor : Colors.white;
    final borderColor = isDark ? _kInputBorderColor : const Color(0xFFE2E8F0);
    final activeColor = isDark ? _kAccentCyan : const Color(0xFF4F46E5);
    final inactiveColor = isDark ? _kHintTextColor : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        backgroundColor: backgroundColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: translate('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.assignment_outlined), label: translate('history')),
          BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet_outlined), label: translate('earnings')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), label: translate('profile')),
        ],
      ),
    );
  }
}
