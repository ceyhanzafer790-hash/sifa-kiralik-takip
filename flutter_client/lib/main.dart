import 'package:flutter/material.dart';

import 'screens/auth_root.dart';
import 'services/api_config.dart';
import 'services/local_catalog_seed_service.dart';
import 'widgets/sifa_brand.dart';

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
    const navy = SifaBrand.charcoal;
    const warmGold = SifaBrand.gold;
    const canvas = SifaBrand.ivory;

    final scheme = ColorScheme.fromSeed(
      seedColor: warmGold,
      brightness: Brightness.light,
    ).copyWith(
      primary: navy,
      secondary: warmGold,
      surface: const Color(0xFFFFFFFF),
      surfaceContainerHighest: const Color(0xFFF4F4F1),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Şifa Kiralık Takip',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: SifaBrand.charcoal,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: SifaBrand.gold),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: navy,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          headlineSmall: TextStyle(
            color: navy,
            fontWeight: FontWeight.w900,
          ),
          titleLarge: TextStyle(
            color: navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.black.withOpacity(0.07),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: warmGold,
              width: 1.6,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0.8,
          shadowColor: Colors.black.withOpacity(0.08),
          surfaceTintColor: Colors.transparent,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.black.withOpacity(0.045),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 74,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: warmGold.withOpacity(0.16),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w900
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? navy
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 3,
          backgroundColor: warmGold,
          foregroundColor: navy,
          shape: StadiumBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: SifaBrand.charcoal,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SifaBrand.charcoal,
            side: const BorderSide(color: SifaBrand.gold),
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        chipTheme: ChipThemeData(
          side: BorderSide(color: Colors.black.withOpacity(0.07)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.black.withOpacity(0.07),
          thickness: 1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: SifaBrand.ivory,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          dragHandleColor: SifaBrand.gold,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: navy,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const AuthRoot(),
    );
  }
}
