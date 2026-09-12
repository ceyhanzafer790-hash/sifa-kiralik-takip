import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';

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
      appBar: AppBar(title: const Text('Üretime Hazırlık')),
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
                    Icon(
                      ready
                          ? Icons.verified_outlined
                          : Icons.build_circle_outlined,
                      size: 34,
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

                return Card(
                  child: ListTile(
                    leading: Icon(icon),
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
                      style: const TextStyle(
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
