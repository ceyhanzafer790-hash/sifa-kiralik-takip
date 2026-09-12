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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Şifa Kiralık Takip',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
        ),
      ),
      home: const AuthRoot(),
    );
  }
}
