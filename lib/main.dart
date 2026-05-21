import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'providers/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: HaazirApp()));
}

class HaazirApp extends ConsumerWidget {
  const HaazirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeProvider);
    
    Widget app = MaterialApp.router(
      title: 'Haazir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.lightPrimary,
        scaffoldBackgroundColor: AppColors.lightBackground,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.darkPrimary,
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: localeState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );

    if (localeState.isEyesProtectionEnabled) {
      app = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.orange.withOpacity(0.15),
          BlendMode.multiply,
        ),
        child: app,
      );
    }

    return app;
  }
}
