import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kSurfaceColor = Color(0xFF161B2E);
  static const Color _kAccentCyan = Color(0xFF00D1FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final locale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    final translate = localeNotifier.translate;

    return Scaffold(
      backgroundColor: locale.isDarkMode ? _kBackgroundColor : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: locale.isDarkMode ? Colors.white : Colors.black),
        title: Text(translate('settings'), style: TextStyle(color: locale.isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ACCOUNT', style: TextStyle(color: _kAccentCyan, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildSettingTile(Icons.lock_reset, translate('change_pin'), isDark: locale.isDarkMode),
            _buildSettingTile(Icons.phone_android, translate('change_phone'), isDark: locale.isDarkMode),
            _buildSettingTile(Icons.lock_outline, translate('forgot_password'), isDark: locale.isDarkMode),
            if (user?.role == 'provider')
              _buildSettingTile(Icons.badge_outlined, translate('reupload_cnic'), isDark: locale.isDarkMode),
            
            const SizedBox(height: 32),
            const Text('PREFERENCES', style: TextStyle(color: _kAccentCyan, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 16),
            
            _buildSwitchTile(
              Icons.dark_mode_outlined, 
              translate('dark_mode'), 
              locale.isDarkMode, 
              (v) => localeNotifier.toggleDarkMode(),
              isDark: locale.isDarkMode
            ),
            
            _buildSwitchTile(
              Icons.visibility_outlined, 
              translate('eye_protection'), 
              locale.isEyesProtectionEnabled, 
              (v) => localeNotifier.toggleEyesProtection(),
              isDark: locale.isDarkMode
            ),

            const SizedBox(height: 32),
            const Text('SUPPORT', style: TextStyle(color: _kAccentCyan, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildSettingTile(Icons.help_outline, translate('help_support'), onTap: () => context.push('/support'), isDark: locale.isDarkMode),
            _buildSettingTile(Icons.info_outline, 'About HAAZIR', isDark: locale.isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, {VoidCallback? onTap, bool isDark = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? _kSurfaceColor : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
          title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white30 : Colors.black26),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, bool value, Function(bool) onChanged, {bool isDark = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? _kSurfaceColor : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
          title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _kAccentCyan,
          ),
        ),
      ),
    );
  }
}
