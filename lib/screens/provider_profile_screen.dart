import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/provider_app_bar.dart';
import '../widgets/provider_bottom_nav.dart';
import '../widgets/provider_drawer.dart';
import '../utils/dialog_helper.dart';

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key});

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);

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
          onConfirm: () => context.go('/provider_profile'),
        );
      });
    }

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final accentColor = isDark ? _kDarkAccentCyan : const Color(0xFF4F46E5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: const ProviderDrawer(),
      appBar: const ProviderAppBar(title: 'My Profile'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: accentColor,
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
                        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt, size: 20, color: isDark ? _kDarkBackgroundColor : Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Provider Name',
                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                user?.phone ?? '',
                style: TextStyle(color: textSecondaryColor, fontSize: 16),
              ),
              // CNIC Section
              if (user?.role == 'provider') ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.credit_card_outlined, color: accentColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'CNIC Information',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CNIC Number: ${user?.cnic ?? 'Not provided'}',
                        style: TextStyle(color: textSecondaryColor, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      if (user != null && user.cnicUrl != null && user.cnicUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.network(
                                user.cnicUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 160,
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  child: Center(
                                    child: Icon(Icons.broken_image_outlined, color: textSecondaryColor, size: 40),
                                  ),
                                ),
                              ),
                              if (authState.isLoading)
                                Container(
                                  height: 160,
                                  color: Colors.black45,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported_outlined, color: textSecondaryColor, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'No CNIC Card Image Found',
                                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery);
                                  if (picked != null) {
                                    try {
                                      await ref.read(authProvider.notifier).uploadCnicPicture(File(picked.path));
                                      if (context.mounted) {
                                        DialogHelper.showSuccess(
                                          context: context,
                                          title: translate('success_title'),
                                          message: translate('cnic_uploaded_msg'),
                                          buttonText: translate('ok'),
                                          isDark: isDark,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Upload failed: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                          icon: authState.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file, color: Colors.white),
                          label: Text(
                            authState.isLoading ? 'Uploading...' : 'Re-upload CNIC Card',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _buildProfileTile(Icons.star_outline, 'My Evaluation', isDark, surfaceColor, accentColor, textColor, borderColor, onTap: () => context.push('/provider_evaluation')),
              _buildProfileTile(Icons.edit, translate('edit_profile'), isDark, surfaceColor, accentColor, textColor, borderColor, onTap: () => context.push('/edit_profile')),
              _buildProfileTile(Icons.settings, translate('settings'), isDark, surfaceColor, accentColor, textColor, borderColor, onTap: () => context.push('/settings')),
              _buildProfileTile(Icons.help, translate('help_support'), isDark, surfaceColor, accentColor, textColor, borderColor, onTap: () => context.push('/support')),
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
      bottomNavigationBar: const ProviderBottomNav(currentIndex: 3),
    );
  }

  Widget _buildProfileTile(
    IconData icon,
    String title,
    bool isDark,
    Color surfaceColor,
    Color accentColor,
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
          leading: Icon(icon, color: accentColor),
          title: Text(title, style: TextStyle(color: textColor)),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white30 : Colors.black26),
          onTap: onTap,
        ),
      ),
    );
  }
}

