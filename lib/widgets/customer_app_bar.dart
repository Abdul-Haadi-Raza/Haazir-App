import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

class CustomerAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  const CustomerAppBar({super.key, this.actions});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: iconColor, size: 28),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      title: Text(
        'HAAZIR',
        style: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      actions: [
        if (actions != null) ...actions!,
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
        final activeColor = isDark ? const Color(0xFFBDB2FF) : const Color(0xFF6366F1);

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
