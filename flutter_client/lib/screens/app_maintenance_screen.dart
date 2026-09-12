import 'package:flutter/material.dart';

import '../services/app_status_service.dart';
import '../services/app_version.dart';

class AppMaintenanceScreen extends StatefulWidget {
  const AppMaintenanceScreen({super.key});

  @override
  State<AppMaintenanceScreen> createState() =>
      _AppMaintenanceScreenState();
}

class _AppMaintenanceScreenState extends State<AppMaintenanceScreen> {
  final service = AppStatusService();
  final messageController = TextEditingController();
  final minController = TextEditingController();
  final latestController = TextEditingController();

  bool maintenance = false;
  bool enforceVersion = false;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    messageController.dispose();
    minController.dispose();
    latestController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final status = await service.fetch();
      if (!mounted) return;

      setState(() {
        maintenance = status.maintenanceMode;
        enforceVersion = status.enforceMinClientVersion;
        messageController.text =
            status.maintenanceMessage ?? '';
        minController.text = status.minClientVersion;
        latestController.text = status.latestClientVersion;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (minController.text.trim().isEmpty ||
        latestController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sürüm alanları boş bırakılamaz.'),
        ),
      );
      return;
    }

    if (enforceVersion) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Eski Sürümleri Engelle'),
          content: Text(
            'Minimum sürüm ${minController.text.trim()} olacak. '
            'Bundan eski uygulamalar sunucu işlemlerinde 426 alacak. '
            'Bütün aktif cihazların güncellendiğinden emin ol.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet ve Uygula'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => saving = true);

    try {
      await service.updateAdmin(
        maintenanceMode: maintenance,
        maintenanceMessage: messageController.text,
        minClientVersion: minController.text,
        latestClientVersion: latestController.text,
        enforceMinClientVersion: enforceVersion,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uygulama çalışma ayarları kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayar kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bakım ve Sürüm Yönetimi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Bu cihazın uygulama sürümü: ${AppVersion.current}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(error!),
              ),
            ),
          SwitchListTile(
            title: const Text(
              'Bakım Modu',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Açıkken Staff hesapları yeni veri yazamaz. Admin çalışmaya devam eder.',
            ),
            value: maintenance,
            onChanged: loading
                ? null
                : (value) => setState(() => maintenance = value),
          ),
          TextField(
            controller: messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bakım mesajı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: latestController,
            decoration: const InputDecoration(
              labelText: 'En güncel uygulama sürümü',
              hintText: '0.24.0',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: minController,
            decoration: const InputDecoration(
              labelText: 'Minimum desteklenen sürüm',
              hintText: '0.20.0',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(
              'Minimum sürümü zorunlu tut',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Açılmadan önce bütün aktif cihazlar yeni sürüme geçirilmelidir.',
            ),
            value: enforceVersion,
            onChanged: loading
                ? null
                : (value) => setState(() => enforceVersion = value),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(saving ? 'Kaydediliyor…' : 'AYARLARI KAYDET'),
            ),
          ),
        ],
      ),
    );
  }
}
