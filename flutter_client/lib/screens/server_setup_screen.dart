import 'package:flutter/material.dart';

import '../services/api_config.dart';

class ServerSetupScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const ServerSetupScreen({
    super.key,
    required this.onSaved,
  });

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  late final TextEditingController address;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    address = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ApiConfig.setBaseUrl(address.text);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is FormatException ? e.message.toString() : e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.dns_outlined, size: 64),
                const SizedBox(height: 14),
                Text(
                  'Şifa İnşaat sunucu bağlantısı',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sunucu henüz hazır değilse uygulamayı kurulu bırakabilirsiniz. '
                  'Merkez sunucu hazır olduğunda adresi buraya girmeniz yeterli; '
                  'APK\'yı yeniden kurmanız gerekmez.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: address,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => saving ? null : _save(),
                  decoration: const InputDecoration(
                    labelText: 'Sunucu adresi',
                    hintText: 'https://api.sifains.com',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(saving ? 'Kaydediliyor…' : 'KAYDET VE DEVAM ET'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Adres yalnızca bu cihazda saklanır ve daha sonra menüden değiştirilebilir.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
