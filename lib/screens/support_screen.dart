import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final accentColor = isDark ? _kDarkAccentCyan : const Color(0xFF4F46E5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Help & Support', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frequently Asked Questions', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            _buildFAQTile('How do I book a service?', 'Go to the home screen, describe your problem in the chat, and our AI will find the best provider for you.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('How can I pay for services?', 'Currently, we support Cash on Delivery. Online payment methods are coming soon.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('How to become a provider?', 'Select "Service Provider" during signup and upload your CNIC for verification.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('Is HAAZIR available 24/7?', 'Yes, the app is available 24/7, but provider availability depends on their working hours.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('What if I am not satisfied?', 'You can rate the provider and leave feedback. Our support team reviews all negative feedback.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('Can I cancel a booking?', 'Yes, you can cancel before the provider starts moving to your location.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('How is my data protected?', 'We use industry-standard encryption and follow strict privacy policies to protect your data.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('Where can I see my history?', 'You can find all your previous bookings in the "History" tab.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('What is Mock Mode?', 'Mock Mode is for demonstration purposes only, allowing you to see how the app looks with data.', textColor, textSecondaryColor, accentColor),
            _buildFAQTile('How to change my PIN?', 'Go to Settings > Account > Change PIN to update your security code.', textColor, textSecondaryColor, accentColor),
            
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Text('Still need help?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Contact our 24/7 support team', style: TextStyle(color: textSecondaryColor, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildContactButton(Icons.email_outlined, 'Email', accentColor, textSecondaryColor, isDark),
                      _buildContactButton(Icons.phone_outlined, 'Call', accentColor, textSecondaryColor, isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chatbot'),
        backgroundColor: accentColor,
        shape: const CircleBorder(),
        child: Icon(Icons.chat_bubble_outline, color: isDark ? _kDarkBackgroundColor : Colors.white),
      ),
    );
  }



  Widget _buildFAQTile(String question, String answer, Color textColor, Color textSecondaryColor, Color accentColor) {
    return Theme(
      data: ThemeData().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(question, style: TextStyle(color: textColor, fontSize: 14)),
        iconColor: accentColor,
        collapsedIconColor: textSecondaryColor.withOpacity(0.5),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: TextStyle(color: textSecondaryColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(IconData icon, String label, Color accentColor, Color textSecondaryColor, bool isDark) {
    return Column(
      children: [
        IconButton(
          onPressed: () {},
          icon: Icon(icon, color: accentColor),
          style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: textSecondaryColor, fontSize: 10)),
      ],
    );
  }
}

