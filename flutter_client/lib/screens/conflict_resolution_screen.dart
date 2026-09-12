import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../services/conflict_diff_service.dart';
import '../services/conflict_service.dart';

class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends State<ConflictResolutionScreen> {
  final service = ConflictService();
  final diffService = ConflictDiffService();

  List<SyncConflict> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await service.openConflicts();
    if (mounted) {
      setState(() {
        rows = result;
        loading = false;
      });
    }
  }

  Future<void> _open(SyncConflict conflict) async {
    final diffs = diffService.build(conflict);

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Senkron Çakışması'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conflict.message,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aynı kayıt başka bir cihazda da değiştirilmiş. '
                  'Farklı alanlar aşağıda gösteriliyor.',
                ),
                const SizedBox(height: 16),
                if (diffs.isEmpty)
                  const Text('Karşılaştırılabilir alan bulunamadı.')
                else
                  ...diffs.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      d.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (d.different)
                                    const Chip(
                                      label: Text('Farklı'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _ValueBox(
                                      title: 'Bu cihaz',
                                      value: d.localValue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ValueBox(
                                      title: 'Merkez',
                                      value: d.serverValue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Şimdilik Bırak'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'server'),
            child: const Text('Merkezdeki Sürümü Kullan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'mine'),
            child: const Text('Benim Değişikliğimi Tekrar Uygula'),
          ),
        ],
      ),
    );

    if (action == null) return;

    try {
      if (action == 'server') {
        await service.useServer(conflict);
      } else if (action == 'mine') {
        await service.retryMine(conflict);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Çakışma şu an çözülemedi: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Senkron Çakışmaları')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'İki cihaz aynı kaydı değiştirirse uygulama birini '
                  'sessizce ezmez. Alanları karşılaştırıp hangi değişikliğin '
                  'devam edeceğini seçebilirsin.',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            if (!loading && rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Çözülmeyi bekleyen çakışma yok.'),
                ),
              ),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.sync_problem_outlined),
                    title: Text(
                      _label(r.operationType),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${r.message}\n${r.createdAt}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String type) => switch (type) {
        'changeInvoicePreference' => 'Fatura tercihi',
        'updateBillingPeriod' => 'Fatura / tahsilat dönemi',
        _ => type,
      };
}

class _ValueBox extends StatelessWidget {
  final String title;
  final String value;

  const _ValueBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
