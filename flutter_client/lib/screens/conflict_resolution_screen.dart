import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../services/conflict_diff_service.dart';
import '../services/conflict_service.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

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
      appBar: AppBar(
        title: const Text(
          'Senkron Çakışmaları',
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
                          Icons.sync_problem_outlined,
                          color: SifaBrand.gold,
                          size: 27,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Aynı kayıt iki cihazda değiştiğinde hangi sürümün devam edeceğini burada seç.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Açık çakışma',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusPill(
                          label: '${rows.length}',
                          tone: rows.isEmpty
                              ? AppStatusTone.success
                              : AppStatusTone.warning,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ],
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
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.sync_problem_outlined,
                        color: Color(0xFF9A5D00),
                      ),
                    ),
                    title: Text(
                      _label(r.operationType),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${r.message}\n${r.createdAt}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: SifaBrand.deepGold,
                    ),
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
        color: SifaBrand.ivory,
        border: Border.all(
          color: SifaBrand.softGrey,
        ),
        borderRadius: BorderRadius.circular(12),
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
