import 'package:flutter/material.dart';

import '../services/app_status_service.dart';
import '../services/app_version.dart';
import '../widgets/sifa_brand.dart';

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
      appBar: AppBar(
        title: const Text(
          'Bakım ve Sürüm Yönetimi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: SifaBrand.gold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: SifaBrand.charcoal,
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.system_update_alt_outlined,
                        color: SifaBrand.gold,
                        size: 28,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uygulama Çalışma Ayarları',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Bakım modu ve desteklenen sürüm sınırlarını yönet.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_android_outlined,
                        color: SifaBrand.deepGold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bu cihazdaki sürüm',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        'v${AppVersion.current}',
                        style: const TextStyle(
                          color: SifaBrand.deepGold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: maintenance
                      ? const Color(0xFFFFF4E5)
                      : SifaBrand.ivory,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.build_circle_outlined,
                  color: maintenance
                      ? const Color(0xFF9A5D00)
                      : SifaBrand.textGrey,
                ),
              ),
              title: const Text(
                'Bakım Modu',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Açıkken Personel hesapları yeni veri yazamaz. Yönetici çalışmaya devam eder.',
              ),
              value: maintenance,
              onChanged: loading
                  ? null
                  : (value) => setState(() => maintenance = value),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bakım mesajı',
              prefixIcon: Icon(Icons.message_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: latestController,
            decoration: const InputDecoration(
              labelText: 'En güncel uygulama sürümü',
              hintText: '0.25.0',
              prefixIcon: Icon(Icons.new_releases_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: minController,
            decoration: const InputDecoration(
              labelText: 'Minimum desteklenen sürüm',
              hintText: '0.20.0',
              prefixIcon: Icon(Icons.security_update_warning_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enforceVersion
                      ? const Color(0xFFFFECEC)
                      : SifaBrand.ivory,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.security_update_warning_outlined,
                  color: enforceVersion
                      ? const Color(0xFFA53C3C)
                      : SifaBrand.textGrey,
                ),
              ),
              title: const Text(
                'Minimum sürümü zorunlu tut',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Açılmadan önce bütün aktif cihazların desteklenen sürüme geçirilmesi gerekir.',
              ),
              value: enforceVersion,
              onChanged: loading
                  ? null
                  : (value) => setState(() => enforceVersion = value),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(saving ? 'Kaydediliyor…' : 'Ayarları Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
