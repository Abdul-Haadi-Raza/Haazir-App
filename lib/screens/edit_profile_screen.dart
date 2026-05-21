import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pinnedLocationCtrl = TextEditingController();

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);

  static const Color _kLightBackgroundColor = Color(0xFFF8FAFC);
  static const Color _kLightSurfaceColor = Colors.white;
  static const Color _kLightAccentIndigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl.text = user?.name ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _addressCtrl.text = user?.address ?? '';
    _pinnedLocationCtrl.text = user?.pinnedLocation ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _pinnedLocationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final translate = ref.read(localeProvider.notifier).translate;
    final isLoading = ref.watch(authProvider).isLoading;

    final backgroundColor = isDark ? _kDarkBackgroundColor : _kLightBackgroundColor;
    final surfaceColor = isDark ? _kDarkSurfaceColor : _kLightSurfaceColor;
    final accentColor = isDark ? _kDarkAccentCyan : _kLightAccentIndigo;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final borderSideColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          translate('edit_profile'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField(translate('full_name'), _nameCtrl, isDark, surfaceColor, textColor, textSecondaryColor, borderSideColor, accentColor),
            const SizedBox(height: 20),
            _buildTextField(translate('mobile_number'), _phoneCtrl, isDark, surfaceColor, textColor, textSecondaryColor, borderSideColor, accentColor, enabled: false),
            const SizedBox(height: 20),
            _buildTextField(
              translate('home_address_hint'),
              _addressCtrl,
              isDark,
              surfaceColor,
              textColor,
              textSecondaryColor,
              borderSideColor,
              accentColor,
              hint: 'e.g. House 45, Street 12, G-11/2, Islamabad',
            ),
            const SizedBox(height: 20),
            _buildTextField(
              'Pinned Location (GPS Coordinates)',
              _pinnedLocationCtrl,
              isDark,
              surfaceColor,
              textColor,
              textSecondaryColor,
              borderSideColor,
              accentColor,
              hint: 'e.g. 33.6844, 73.0479',
              suffixIcon: IconButton(
                icon: Icon(Icons.my_location, color: accentColor),
                onPressed: () {
                  // Simulate fetching current coordinates
                  _pinnedLocationCtrl.text = "33.6844, 73.0479";
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(translate('online')), // Or a simple text
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (_nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(translate('err_name_empty'))),
                    );
                    return;
                  }
                  try {
                    await ref.read(authProvider.notifier).updateProfile(
                      name: _nameCtrl.text.trim(),
                      address: _addressCtrl.text.trim(),
                      pinnedLocation: _pinnedLocationCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      final user = ref.read(authProvider).user;
                      if (user?.role == 'provider') {
                        context.go('/provider_profile?saved=true');
                      } else {
                        context.go('/profile?saved=true');
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating profile: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading 
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: isDark ? _kDarkBackgroundColor : Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      translate('save_changes'),
                      style: TextStyle(
                        color: isDark ? _kDarkBackgroundColor : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderSideColor,
    Color accentColor, {
    bool enabled = true,
    String? hint,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSecondaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          enabled: enabled,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceColor,
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderSideColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderSideColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderSideColor.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor),
            ),
          ),
        ),
      ],
    );
  }
}
