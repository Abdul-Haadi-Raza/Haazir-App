import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';

class CustomerBottomNav extends ConsumerWidget {
  final int currentIndex;
  const CustomerBottomNav({super.key, required this.currentIndex});

  static const Color _kInputBorderColor = Color(0xFF2E344A);
  static const Color _kHintTextColor = Color(0xFF6B7280);
  static const Color _kPrimaryPurple = Color(0xFFBDB2FF);

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/history');
        break;
      case 2:
        context.go('/nearby');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF0A0F1D) : Colors.white;
    final borderColor = isDark ? _kInputBorderColor : const Color(0xFFE2E8F0);
    final activeColor = isDark ? _kPrimaryPurple : const Color(0xFF4F46E5);
    final inactiveColor = isDark ? _kHintTextColor : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        backgroundColor: backgroundColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Nearby'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
