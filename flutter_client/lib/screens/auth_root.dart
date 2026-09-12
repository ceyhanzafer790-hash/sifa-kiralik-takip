import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'server_setup_screen.dart';

class AuthRoot extends StatefulWidget {
  const AuthRoot({super.key});

  @override
  State<AuthRoot> createState() => _AuthRootState();
}

class _AuthRootState extends State<AuthRoot> {
  final auth = AuthService();
  bool? hasSession;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await auth.hasSession();
    if (mounted) setState(() => hasSession = value);
  }

  Future<void> _openServerSetup() async {
    await auth.logout();
    await ApiConfig.clear();
    if (mounted) {
      setState(() => hasSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.configured) {
      return ServerSetupScreen(
        onSaved: () => setState(() {}),
      );
    }

    if (hasSession == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasSession == false) {
      return LoginScreen(
        onLoggedIn: () => setState(() => hasSession = true),
        onServerSettings: _openServerSetup,
      );
    }

    return AppShell(
      onLogout: () async {
        await auth.logout();
        if (mounted) setState(() => hasSession = false);
      },
      onServerSettings: _openServerSetup,
    );
  }
}
