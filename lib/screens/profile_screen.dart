import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/customer_app_bar.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/customer_drawer.dart';
import '../utils/dialog_helper.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkPrimaryPurple = Color(0xFFBDB2FF);

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await ref.read(authProvider.notifier).uploadProfilePicture(File(pickedFile.path));
      if (context.mounted) {
        final translate = ref.read(localeProvider.notifier).translate;
        final isDark = ref.read(localeProvider).isDarkMode;
        DialogHelper.showSuccess(
          context: context,
          title: translate('success_title'),
          message: translate('profile_pic_updated_msg'),
          buttonText: translate('ok'),
          isDark: isDark,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final translate = ref.read(localeProvider.notifier).translate;

    final savedParam = GoRouterState.of(context).uri.queryParameters['saved'];
    if (savedParam == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DialogHelper.showSuccess(
          context: context,
          title: translate('success_title'),
          message: translate('changes_saved_msg'),
          buttonText: translate('ok'),
          isDark: isDark,
          onConfirm: () => context.go('/profile'),
        );
      });
    }

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final primaryPurple = isDark ? _kDarkPrimaryPurple : const Color(0xFF4F46E5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomerAppBar(),
      drawer: const CustomerDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryPurple,
                    backgroundImage: authState.profileImageUrl != null 
                        ? NetworkImage(authState.profileImageUrl!) 
                        : null,
                    child: authState.profileImageUrl == null 
                        ? Icon(Icons.person, size: 50, color: isDark ? _kDarkBackgroundColor : Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage(context, ref),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: primaryPurple, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt, size: 20, color: isDark ? _kDarkBackgroundColor : Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Guest User',
                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                user?.phone ?? '',
                style: TextStyle(color: textSecondaryColor, fontSize: 16),
              ),
              const SizedBox(height: 32),
              _buildProfileTile(Icons.edit, translate('edit_profile'), isDark, surfaceColor, primaryPurple, textColor, borderColor, onTap: () => context.push('/edit_profile')),
              _buildProfileTile(Icons.location_on, translate('saved_addresses_title'), isDark, surfaceColor, primaryPurple, textColor, borderColor, onTap: () => context.push('/saved_addresses')),
              _buildProfileTile(Icons.settings, translate('settings'), isDark, surfaceColor, primaryPurple, textColor, borderColor, onTap: () => context.push('/settings')),
              _buildProfileTile(Icons.help, translate('help_support'), isDark, surfaceColor, primaryPurple, textColor, borderColor, onTap: () => context.push('/support')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chatbot'),
        backgroundColor: primaryPurple,
        shape: const CircleBorder(),
        child: Icon(Icons.chat_bubble_outline, color: isDark ? _kDarkBackgroundColor : Colors.white),
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 3),
    );
  }

  Widget _buildProfileTile(
    IconData icon,
    String title,
    bool isDark,
    Color surfaceColor,
    Color primaryPurple,
    Color textColor,
    Color borderColor, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          tileColor: surfaceColor,
          leading: Icon(icon, color: primaryPurple),
          title: Text(title, style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white30 : Colors.black26),
          onTap: onTap,
        ),
      ),
    );
  }
}

