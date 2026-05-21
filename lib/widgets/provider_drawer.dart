import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class ProviderDrawer extends ConsumerWidget {
  const ProviderDrawer({super.key});

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kSurfaceColor = Color(0xFF161B2E);
  static const Color _kAccentCyan = Color(0xFF00D1FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final translate = ref.read(localeProvider.notifier).translate;
    final isDark = ref.watch(localeProvider).isDarkMode;

    final backgroundColor = isDark ? _kBackgroundColor : Colors.white;
    final headerColor = isDark ? _kSurfaceColor : const Color(0xFF4F46E5);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final textColor = isDark ? Colors.white : Colors.black87;


    return Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 50, bottom: 24, left: 16, right: 16),
            decoration: BoxDecoration(
              color: headerColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: isDark ? _kAccentCyan.withOpacity(0.15) : Colors.white24,
                    backgroundImage: ref.watch(authProvider).profileImageUrl != null 
                        ? NetworkImage(ref.watch(authProvider).profileImageUrl!) 
                        : null,
                    child: ref.watch(authProvider).profileImageUrl == null
                        ? Text(
                            user?.name != null && user!.name.isNotEmpty ? user.name[0].toUpperCase() : 'P',
                            style: TextStyle(
                              color: isDark ? _kAccentCyan : Colors.white, 
                              fontSize: 32, 
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Provider', 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.phone ?? '', 
                    style: const TextStyle(
                      color: Colors.white70, 
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, color: iconColor),
            title: Text(translate('home'), style: TextStyle(color: textColor)),
            onTap: () {
              context.pop();
              context.go('/provider_dashboard');
            },
          ),
          ListTile(
            leading: Icon(Icons.assignment_outlined, color: iconColor),
            title: Text(translate('history'), style: TextStyle(color: textColor)),
            onTap: () {
              context.pop();
              context.go('/provider_history');
            },
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet_outlined, color: iconColor),
            title: Text(translate('earnings'), style: TextStyle(color: textColor)),
            onTap: () {
              context.pop();
              context.go('/provider_earnings');
            },
          ),
          ListTile(
            leading: Icon(Icons.star_outline, color: iconColor),
            title: Text('Evaluations', style: TextStyle(color: textColor)),
            onTap: () {
              context.pop();
              context.push('/provider_evaluation');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: iconColor),
            title: Text(translate('settings'), style: TextStyle(color: textColor)),
            onTap: () {
              context.pop();
              context.push('/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.person_outline, color: iconColor),
            title: Text(translate('profile'), style: TextStyle(color: textColor)),
            onTap: () {
              context.pop();
              context.go('/provider_profile');
            },
          ),
          const Spacer(),
          Divider(color: isDark ? Colors.white24 : Colors.black12),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(translate('logout'), style: const TextStyle(color: Colors.redAccent)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
