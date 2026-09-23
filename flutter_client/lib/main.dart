import 'package:flutter/material.dart';

import 'screens/auth_root.dart';
import 'services/api_config.dart';
import 'services/local_catalog_seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  await LocalCatalogSeedService().ensureSeeded();
  runApp(const SifaKiralikTakipApp());
}

class SifaKiralikTakipApp extends StatelessWidget {
  const SifaKiralikTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF24324A);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Şifa Kiralık Takip',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF7F7F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F5),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF7F7F5),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: seed,
              width: 1.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 1,
        ),
      ),
      home: const AuthRoot(),
    );
  }
}
