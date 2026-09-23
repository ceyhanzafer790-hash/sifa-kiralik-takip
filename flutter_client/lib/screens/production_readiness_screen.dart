import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';
import '../widgets/sifa_brand.dart';

class ProductionReadinessScreen extends StatefulWidget {
  const ProductionReadinessScreen({super.key});

  @override
  State<ProductionReadinessScreen> createState() =>
      _ProductionReadinessScreenState();
}

class _ProductionReadinessScreenState
    extends State<ProductionReadinessScreen> {
  final repo = AdminApiRepository();

  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await repo.productionReadiness();
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((data?['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final ready = data?['ready'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Üretime Hazırlık',
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ready
                            ? SifaBrand.successBg
                            : const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        ready
                            ? Icons.verified_outlined
                            : Icons.build_circle_outlined,
                        color: ready
                            ? SifaBrand.success
                            : const Color(0xFF9A5D00),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            ready
                                ? 'Temel üretim kontrolleri geçti'
                                : 'Üretime geçmeden önce eksikler var',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '${data?['failure_count'] ?? 0} kritik eksik • '
                            '${data?['warning_count'] ?? 0} uyarı',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(error!),
                ),
              ),
            ...items.map(
              (item) {
                final status =
                    item['status']?.toString() ?? 'warn';

                final icon = switch (status) {
                  'pass' => Icons.check_circle_outline,
                  'fail' => Icons.cancel_outlined,
                  _ => Icons.warning_amber_outlined,
                };

                final foreground = switch (status) {
                  'pass' => SifaBrand.success,
                  'fail' => const Color(0xFFA53C3C),
                  _ => const Color(0xFF9A5D00),
                };
                final background = switch (status) {
                  'pass' => SifaBrand.successBg,
                  'fail' => const Color(0xFFFFECEC),
                  _ => const Color(0xFFFFF4E5),
                };

                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: foreground),
                    ),
                    title: Text(
                      item['title']?.toString() ?? 'Kontrol',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      item['detail']?.toString() ?? '',
                    ),
                    trailing: Text(
                      switch (status) {
                        'pass' => 'GEÇTİ',
                        'fail' => 'EKSİK',
                        _ => 'UYARI',
                      },
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Bu ekran gerçek Flutter build, gerçek cihaz senkronu '
                  've yedekten geri yükleme tatbikatının yerine geçmez. '
                  'Onlar üretim öncesi ayrıca yapılacaktır.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
