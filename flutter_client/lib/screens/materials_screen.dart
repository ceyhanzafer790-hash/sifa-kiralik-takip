import 'package:flutter/material.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_config.dart';
import '../services/local_domain_cache.dart';
import '../services/role_service.dart';
import '../services/stock_api_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';
import 'stock_count_screen.dart';
import 'stock_maintenance_screen.dart';
import 'stock_source_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final stockRepo = StockApiRepository();
  final cache = LocalDomainCache();
  final roles = RoleService();

  String query = '';
  ProductCategory? selectedCategory;
  final Map<String, Map<String, dynamic>> summaries = {};
  final Map<String, double> rentedByProduct = {};

  bool loadingStock = true;
  bool canWrite = false;
  String? stockError;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadData();
  }

  Future<void> _loadRole() async {
    final value = await roles.canWrite();
    if (mounted) setState(() => canWrite = value);
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        loadingStock = true;
        stockError = null;
      });
    }

    await Future.wait([
      _loadRentedTotals(),
      _loadStockSummaries(),
    ]);

    if (mounted) setState(() => loadingStock = false);
  }

  Future<void> _loadRentedTotals() async {
    final next = <String, double>{};

    try {
      final customers = await cache.customers();

      for (final customer in customers) {
        final rentals = await cache.rentalsForCustomer(customer.id);

        for (final rental in rentals) {
          final items = await cache.rentalItems(rental.id);
          final movements = await cache.movements(rental.id);

          for (final item in items) {
            final returned = movements
                .where(
                  (movement) =>
                      movement.rentalItemId == item.id &&
                      movement.movementType == 'inbound_return',
                )
                .fold<double>(
                  0,
                  (sum, movement) => sum + movement.quantity,
                );

            final remaining =
                (item.initialQuantity - returned).clamp(
                  0.0,
                  double.infinity,
                );

            if (remaining > 0) {
              next[item.productId] =
                  (next[item.productId] ?? 0) + remaining.toDouble();
            }
          }
        }
      }
    } catch (_) {
      // Yerel kira verisi eksikse ekran yine açılmaya devam eder.
    }

    if (mounted) {
      setState(() {
        rentedByProduct
          ..clear()
          ..addAll(next);
      });
    }
  }

  Future<void> _loadStockSummaries() async {
    if (!ApiConfig.configured) {
      if (mounted) {
        setState(() {
          summaries.clear();
          stockError =
              'Sunucu bağlı değil. Kiradaki miktarlar yerel kayıtlardan gösteriliyor.';
        });
      }
      return;
    }

    final next = <String, Map<String, dynamic>>{};
    var hadError = false;

    for (var i = 0; i < products.length; i += 6) {
      final end =
          i + 6 < products.length ? i + 6 : products.length;
      final batch = products.sublist(i, end);

      final results = await Future.wait(
        batch.map((product) async {
          try {
            final summary = await stockRepo.productSummary(product.id);
            return MapEntry(product.id, summary);
          } catch (_) {
            hadError = true;
            return null;
          }
        }),
      );

      for (final result in results) {
        if (result != null) {
          next[result.key] = result.value;
        }
      }

      if (mounted) {
        setState(() {
          summaries
            ..clear()
            ..addAll(next);
        });
      }
    }

    if (mounted && hadError) {
      setState(() {
        stockError = next.isEmpty
            ? 'Stok özetleri alınamadı.'
            : 'Bazı stok özetleri alınamadı. Görünen değerler son alınabilen verilerdir.';
      });
    }
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = products.where((product) {
      final matchesQuery = q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.category.label.toLowerCase().contains(q);
      final matchesCategory =
          selectedCategory == null || product.category == selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    final knownStockCount = summaries.length;
    final rentedProductCount =
        rentedByProduct.values.where((value) => value > 0).length;
    final attentionCount = products.where((product) {
      final summary = summaries[product.id];
      if (summary == null) return false;
      return _value(summary['repair']) > 0 ||
          _value(summary['scrap']) > 0 ||
          _value(summary['lost']) > 0;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Malzemeler',
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
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            color: SifaBrand.charcoal,
                            padding:
                                const EdgeInsets.fromLTRB(16, 15, 16, 15),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color:
                                          SifaBrand.gold.withOpacity(0.45),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: SifaBrand.gold,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Stok & Malzeme Merkezi',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Depoda, kirada ve sorunlu stokları tek yerde gör.',
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
                            padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 13),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _OverviewMetric(
                                    label: 'Stok Verisi',
                                    value: '$knownStockCount',
                                    icon: Icons.warehouse_outlined,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: _OverviewMetric(
                                    label: 'Kirada',
                                    value: '$rentedProductCount',
                                    icon: Icons.local_shipping_outlined,
                                    emphasize: rentedProductCount > 0,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: _OverviewMetric(
                                    label: 'Dikkat',
                                    value: '$attentionCount',
                                    icon: Icons.build_circle_outlined,
                                    warning: attentionCount > 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canWrite) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _open(const StockCountScreen()),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Depo Sayımı'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _open(const StockSourceScreen()),
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Stok Girişi'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _open(const StockMaintenanceScreen()),
                            icon: const Icon(Icons.build_outlined),
                            label: const Text('Durum Yönetimi'),
                          ),
                        ],
                      ),
                    ],
                    if (loadingStock) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (stockError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF9A5D00),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                stockError!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Malzeme ara',
                      ),
                      onChanged: (value) =>
                          setState(() => query = value),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: const Text('Tümü'),
                              selected: selectedCategory == null,
                              onSelected: (_) =>
                                  setState(() => selectedCategory = null),
                            ),
                          ),
                          ...ProductCategory.values.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(category.label),
                                selected:
                                    selectedCategory == category,
                                onSelected: (_) => setState(
                                  () => selectedCategory = category,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Malzeme Listesi',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        StatusPill(
                          label: '${filtered.length} kalem',
                          tone: AppStatusTone.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Aramaya uyan malzeme bulunamadı.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final summary = summaries[product.id];
                    final rented = rentedByProduct[product.id] ?? 0;

                    return _MaterialCard(
                      product: product,
                      summary: summary,
                      rented: rented,
                      loading: loadingStock && summary == null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static double _value(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

class _OverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;
  final bool warning;

  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = warning
        ? const Color(0xFF9A5D00)
        : emphasize
            ? SifaBrand.deepGold
            : SifaBrand.charcoal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFFFF4E5)
            : emphasize
                ? SifaBrand.goldBg
                : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning
              ? const Color(0xFFF1D8AF)
              : emphasize
                  ? SifaBrand.gold.withOpacity(0.35)
                  : SifaBrand.softGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: SifaBrand.textGrey,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Product product;
  final Map<String, dynamic>? summary;
  final double rented;
  final bool loading;

  const _MaterialCard({
    required this.product,
    required this.summary,
    required this.rented,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final available = _value(summary?['available']);
    final repair = _value(summary?['repair']);
    final scrap = _value(summary?['scrap']);
    final lost = _value(summary?['lost']);
    final confidence = summary?['confidence']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: rented > 0
                        ? SifaBrand.goldBg
                        : SifaBrand.ivory,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rented > 0
                          ? SifaBrand.gold.withOpacity(0.35)
                          : SifaBrand.softGrey,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: SifaBuildingMark(
                    size: 29,
                    gold: rented > 0,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${product.category.label} • '
                        '${product.unit.label} • '
                        '${product.tradeMode.label}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: SifaBrand.textGrey,
                                ),
                      ),
                    ],
                  ),
                ),
                if (summary != null)
                  _StockConfidence(confidence: confidence),
              ],
            ),
            const SizedBox(height: 12),
            if (summary == null && loading)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stok verisi yükleniyor…',
                  style: TextStyle(
                    color: SifaBrand.textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (summary == null && rented <= 0)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stok özeti alınamadı.',
                  style: TextStyle(
                    color: SifaBrand.textGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _StockMetric(
                      label: 'Depoda',
                      value: available,
                      unit: product.unit.label,
                      icon: Icons.warehouse_outlined,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _StockMetric(
                      label: 'Kirada',
                      value: rented,
                      unit: product.unit.label,
                      icon: Icons.local_shipping_outlined,
                      emphasize: rented > 0,
                    ),
                  ),
                ],
              ),
            if (repair > 0 || scrap > 0 || lost > 0) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (repair > 0)
                    _IssuePill(
                      label: 'Tamirlik',
                      value: repair,
                      unit: product.unit.label,
                      icon: Icons.build_outlined,
                      tone: AppStatusTone.warning,
                    ),
                  if (scrap > 0)
                    _IssuePill(
                      label: 'Hurda',
                      value: scrap,
                      unit: product.unit.label,
                      icon: Icons.delete_sweep_outlined,
                      tone: AppStatusTone.danger,
                    ),
                  if (lost > 0)
                    _IssuePill(
                      label: 'Kayıp',
                      value: lost,
                      unit: product.unit.label,
                      icon: Icons.help_outline,
                      tone: AppStatusTone.danger,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _value(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final IconData icon;
  final bool emphasize;

  const _StockMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: emphasize ? SifaBrand.goldBg : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: emphasize
              ? SifaBrand.gold.withOpacity(0.35)
              : SifaBrand.softGrey,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: emphasize ? SifaBrand.deepGold : SifaBrand.textGrey,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: SifaBrand.textGrey,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${_number(value)} $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: emphasize
                        ? SifaBrand.deepGold
                        : SifaBrand.charcoal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _number(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }
}

class _IssuePill extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final IconData icon;
  final AppStatusTone tone;

  const _IssuePill({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: '$label ${_StockMetric._number(value)} $unit',
      icon: icon,
      tone: tone,
      compact: true,
    );
  }
}

class _StockConfidence extends StatelessWidget {
  final String? confidence;

  const _StockConfidence({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final counted = confidence == 'counted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: counted ? SifaBrand.successBg : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: counted
              ? SifaBrand.success.withOpacity(0.25)
              : SifaBrand.softGrey,
        ),
      ),
      child: Text(
        counted ? 'Sayılmış' : 'Tahmini',
        style: TextStyle(
          color: counted ? SifaBrand.success : SifaBrand.textGrey,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
