import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/sifa_wordmark.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;
  final VoidCallback onServerSettings;

  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    required this.onServerSettings,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();

  bool loading = false;
  bool obscurePassword = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await auth.login(
        email: email.text,
        password: password.text,
      );
      widget.onLoggedIn();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              right: -34,
              top: 32,
              child: Opacity(
                opacity: 0.07,
                child: SifaBuildingMark(size: 190),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  children: [
                    const Center(
                      child: SifaWordmark(
                        compact: false,
                        showSubtitle: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'İNŞAATIN DAHA AKILLI YÖNETİMİ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SifaBrand.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Hoş Geldin',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: SifaBrand.charcoal,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Kiralama, müşteri ve malzeme takibine devam et.',
                              style: TextStyle(
                                color: SifaBrand.textGrey,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: password,
                              obscureText: obscurePassword,
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon:
                                    const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(
                                      () => obscurePassword =
                                          !obscurePassword,
                                    );
                                  },
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFECEC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: loading ? null : _login,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                child: Text(
                                  loading
                                      ? 'Giriş yapılıyor…'
                                      : 'GİRİŞ YAP',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed:
                          loading ? null : widget.onServerSettings,
                      icon: const Icon(Icons.dns_outlined),
                      label: const Text('Sunucu adresini değiştir'),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Divider(color: SifaBrand.gold),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 9),
                          child: Text(
                            'GÜÇLÜ YAPILAR • GÜVENİLİR ORTAKLIKLAR',
                            style: TextStyle(
                              fontSize: 8,
                              color: SifaBrand.textGrey,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: Divider(color: SifaBrand.gold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
