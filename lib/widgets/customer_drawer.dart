import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class CustomerDrawer extends ConsumerWidget {
  const CustomerDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final authState = ref.watch(authProvider);
    final translate = ref.read(localeProvider.notifier).translate;
    final isDark = ref.watch(localeProvider).isDarkMode;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 50, bottom: 24, left: 16, right: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B2E) : Colors.deepPurple,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: isDark ? const Color(0xFF00D1FF).withOpacity(0.15) : Colors.white24,
                    backgroundImage: authState.profileImageUrl != null ? NetworkImage(authState.profileImageUrl!) : null,
                    child: authState.profileImageUrl == null 
                        ? Text(
                            (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.bold, 
                              color: isDark ? const Color(0xFF00D1FF) : Colors.white,
                            ),
                          ) 
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'User', 
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
            leading: Icon(Icons.home, color: isDark ? Colors.white : Colors.black87),
            title: Text(translate('home'), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              context.pop();
              context.go('/home');
            },
          ),
          ListTile(
            leading: Icon(Icons.history, color: isDark ? Colors.white : Colors.black87),
            title: Text(translate('history'), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              context.pop();
              context.go('/history');
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: isDark ? Colors.white : Colors.black87),
            title: Text(translate('profile'), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              context.pop();
              context.go('/profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
            title: Text(translate('settings'), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              context.pop();
              context.push('/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: isDark ? Colors.white : Colors.black87),
            title: Text(translate('help_support'), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              context.pop();
              context.push('/support');
            },
          ),
          const Spacer(),
          const Divider(color: Colors.white24),
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
