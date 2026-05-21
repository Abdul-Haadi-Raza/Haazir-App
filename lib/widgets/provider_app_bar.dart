import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';

class ProviderAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLanguageSelector;

  const ProviderAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLanguageSelector = true,
  });

  static const Color _kAccentCyan = Color(0xFF00D1FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final appbarTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: iconColor),
      centerTitle: true,
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: appbarTitleColor,
          fontWeight: FontWeight.w900,
          letterSpacing: title == 'HAAZIR' ? 2 : 0,
          shadows: isDark && title == 'HAAZIR' ? [
            const Shadow(color: _kAccentCyan, blurRadius: 10),
          ] : null,
        ),
      ),
      actions: [
        if (actions != null) ...actions!,
        if (showLanguageSelector)
          IconButton(
            icon: Icon(Icons.language, color: isDark ? Colors.white70 : Colors.black54, size: 26),
            onPressed: () => _showLanguageDialog(context, ref),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final isDark = ref.read(localeProvider).isDarkMode;
    final currentLang = ref.read(localeProvider).language;
    final translate = ref.read(localeProvider.notifier).translate;

    showDialog(
      context: context,
      builder: (context) {
        final bgColor = isDark ? const Color(0xFF161B2E) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
        final activeColor = isDark ? const Color(0xFF00D1FF) : const Color(0xFF4F46E5); // Cyan for provider dark, Indigo/Deep Purple for light

        return Dialog(
          backgroundColor: bgColor,
          elevation: 16,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('select_language'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                _buildLanguageOption(
                  context,
                  ref,
                  label: 'English',
                  lang: AppLanguage.en,
                  textColor: textColor,
                  activeColor: activeColor,
                  isSelected: currentLang == AppLanguage.en,
                ),
                const SizedBox(height: 24),
                _buildLanguageOption(
                  context,
                  ref,
                  label: 'Urdu (Roman)',
                  lang: AppLanguage.roman,
                  textColor: textColor,
                  activeColor: activeColor,
                  isSelected: currentLang == AppLanguage.roman,
                ),
                const SizedBox(height: 24),
                _buildLanguageOption(
                  context,
                  ref,
                  label: 'اردو',
                  lang: AppLanguage.urdu,
                  textColor: textColor,
                  activeColor: activeColor,
                  isSelected: currentLang == AppLanguage.urdu,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required AppLanguage lang,
    required Color textColor,
    required Color activeColor,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(localeProvider.notifier).setLanguage(lang);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : textColor,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
