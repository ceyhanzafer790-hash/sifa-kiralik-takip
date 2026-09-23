import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/api_config.dart';
import '../services/offline_sync_service.dart';
import '../services/role_service.dart';
import '../services/sales_api_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

class SalesScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const SalesScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final repo = SalesApiRepository();
  final queue = OfflineSyncService();
  final uuid = const Uuid();
  final roleService = RoleService();

  List<Map<String, dynamic>> sales = [];
  bool canWrite = false;
  bool loading = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRole();
    if (ApiConfig.configured) _load();
  }

  Future<void> _loadRole() async {
    final allowed = await roleService.canWrite();
    if (mounted) setState(() => canWrite = allowed);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await repo.forCustomer(widget.customerId);
      if (mounted) setState(() => sales = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _newSale() async {
    if (!canWrite || saving) return;

    final draft = await Navigator.of(context).push<_SaleDraft>(
      MaterialPageRoute(
        builder: (_) => _NewSaleScreen(
          customerName: widget.customerName,
        ),
      ),
    );
    if (draft == null) return;

    setState(() => saving = true);

    final saleId = uuid.v4();
    final operationId = uuid.v4();
    final payload = {
      'id': saleId,
      'customer_id': widget.customerId,
      'sale_date': _date(draft.date),
      'note': draft.note,
      'items': draft.lines
          .map(
            (line) => {
              'product_id': line.product.id,
              'quantity': line.quantity,
              'unit_price': line.unitPrice,
            },
          )
          .toList(),
    };

    try {
      if (ApiConfig.configured) {
        try {
          await repo.create({
            ...payload,
            'client_operation_id': operationId,
          });

          if (mounted) {
            _message('Satış kaydedildi.');
          }
          await _load();
          return;
        } on ApiException catch (e) {
          if (mounted) {
            _message(e.userMessage);
          }
          return;
        } catch (_) {
          // Gerçek bağlantı problemi varsa kalıcı offline kuyruğa geçer.
        }
      }

      await queue.enqueueWithId(
        operationId,
        SyncOperationType.createSale,
        payload,
      );

      if (mounted) {
        _message(
          'Satış telefona kaydedildi. Bağlantı gelince merkeze gönderilecek.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = sales.fold<double>(
      0,
      (sum, sale) => sum + _value(sale['total_amount']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Satılanlar',
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
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: saving ? null : _newSale,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('Yeni Satış'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: ApiConfig.configured ? _load : () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: SifaBrand.charcoal,
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: SifaBrand.gold.withOpacity(0.45),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sell_outlined,
                            color: SifaBrand.gold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Satış geçmişi ve yeni satış işlemleri',
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
                        Expanded(
                          child: _SalesMetric(
                            label: 'Satış Kaydı',
                            value: sales.length.toString(),
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SalesMetric(
                            label: 'Toplam Satış',
                            value: '${_money(totalSales)} ₺',
                            icon: Icons.currency_lira,
                            emphasize: totalSales > 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!ApiConfig.configured) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: Color(0xFF9A5D00),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yeni satış offline kaydedilebilir. Geçmiş satışlar merkez bağlantısı gelince görünür.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (loading || saving) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Satış geçmişi alınamadı: $error',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Satış Geçmişi',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                StatusPill(
                  label: '${sales.length} kayıt',
                  tone: AppStatusTone.neutral,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (!loading && sales.isEmpty)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: canWrite ? _newSale : null,
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 36,
                          color: SifaBrand.deepGold,
                        ),
                        SizedBox(height: 9),
                        Text(
                          'Henüz satış kaydı yok.',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Satılan malzemeyi eklemek için Yeni Satış kullan.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...sales.map(
                (sale) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: SifaBrand.gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.sell_outlined,
                              color: SifaBrand.deepGold,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_money(_value(sale['total_amount']))} ₺',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _displayDate(sale['sale_date']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (sale['item_count'] != null)
                                      '${sale['item_count']} kalem',
                                    if (sale['note'] != null &&
                                        sale['note'].toString().trim().isNotEmpty)
                                      sale['note'].toString(),
                                  ].join(' • '),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: SifaBrand.textGrey,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const StatusPill(
                            label: 'Tamamlandı',
                            tone: AppStatusTone.success,
                            compact: true,
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
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static double _value(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }

  static String _displayDate(dynamic raw) {
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return raw?.toString() ?? '-';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _NewSaleScreen extends StatefulWidget {
  final String customerName;

  const _NewSaleScreen({
    required this.customerName,
  });

  @override
  State<_NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<_NewSaleScreen> {
  DateTime date = DateTime.now();
  final note = TextEditingController();
  final List<_SaleLine> lines = [];

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  double get total => lines.fold(
        0,
        (sum, line) => sum + line.quantity * line.unitPrice,
      );

  Future<void> _addLine() async {
    final result = await showDialog<_SaleLine>(
      context: context,
      builder: (_) => const _SaleLineDialog(),
    );
    if (result != null) setState(() => lines.add(result));
  }

  Future<void> _editLine(int index) async {
    final result = await showDialog<_SaleLine>(
      context: context,
      builder: (_) => _SaleLineDialog(initial: lines[index]),
    );
    if (result != null && mounted) {
      setState(() => lines[index] = result);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  void _save() {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce en az bir satış kalemi ekle.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _SaleDraft(
        date: date,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
        lines: lines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yeni Satış',
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              color: SifaBrand.charcoal,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_cart_checkout_outlined,
                    color: SifaBrand.gold,
                    size: 27,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Satılacak malzeme, miktar ve fiyatları ekle.',
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
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: SifaBrand.ivory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SifaBrand.softGrey),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: SifaBrand.deepGold,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Satış tarihi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    _displayDate(date),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Satış Kalemleri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (lines.isNotEmpty)
                StatusPill(
                  label: '${lines.length} kalem',
                  tone: AppStatusTone.neutral,
                  compact: true,
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (lines.isEmpty)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _addLine,
                child: const Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 36,
                        color: SifaBrand.deepGold,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Satış kalemi eklenmedi.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Satılacak malzemeyi, miktarı ve fiyatı eklemek için dokun.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...lines.asMap().entries.map(
              (entry) => _SaleLineCard(
                line: entry.value,
                onEdit: () => _editLine(entry.key),
                onDelete: () => setState(
                  () => lines.removeAt(entry.key),
                ),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'İsteğe bağlı açıklama',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const Icon(
                    Icons.calculate_outlined,
                    color: SifaBrand.deepGold,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Satış Toplamı',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${_SalesScreenState._money(total)} ₺',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: SifaBrand.deepGold,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: lines.isEmpty ? null : _save,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Satışı Kaydet'),
          ),
        ],
      ),
    );
  }

  static String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _SaleLineCard extends StatelessWidget {
  final _SaleLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SaleLineCard({
    required this.line,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = line.quantity * line.unitPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SifaBrand.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.sell_outlined,
                    color: SifaBrand.deepGold,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_clean(line.quantity)} ${line.product.unit.label} × '
                        '${_SalesScreenState._money(line.unitPrice)} ₺',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Toplam: ${_SalesScreenState._money(lineTotal)} ₺',
                        style: const TextStyle(
                          color: SifaBrand.deepGold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Düzenle',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: SifaBrand.deepGold,
                  ),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _clean(double value) {
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

class _SaleLineDialog extends StatefulWidget {
  final _SaleLine? initial;

  const _SaleLineDialog({this.initial});

  @override
  State<_SaleLineDialog> createState() => _SaleLineDialogState();
}

class _SaleLineDialogState extends State<_SaleLineDialog> {
  Product? selected;
  late final TextEditingController qty;
  late final TextEditingController price;

  @override
  void initState() {
    super.initState();
    selected = widget.initial?.product;
    qty = TextEditingController(
      text: widget.initial == null
          ? ''
          : _SaleLineCard._clean(widget.initial!.quantity),
    );
    price = TextEditingController(
      text: widget.initial == null
          ? ''
          : _SaleLineCard._clean(widget.initial!.unitPrice),
    );
  }

  @override
  void dispose() {
    qty.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = double.tryParse(qty.text.replaceAll(',', '.')) ?? 0;
    final unitPrice =
        double.tryParse(price.text.replaceAll(',', '.')) ?? 0;
    final lineTotal = quantity * unitPrice;

    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Satış Kalemi Ekle' : 'Satış Kalemini Düzenle',
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Malzeme',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: products
                    .where(
                      (p) =>
                          p.tradeMode == TradeMode.sale ||
                          p.tradeMode == TradeMode.both,
                    )
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selected = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Miktar',
                  suffixText: selected?.unit.label,
                  prefixIcon: const Icon(Icons.numbers_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Birim satış fiyatı',
                  suffixText: '₺',
                  prefixIcon: Icon(Icons.currency_lira),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (quantity > 0 && unitPrice >= 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: SifaBrand.goldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Kalem toplamı: ${_SalesScreenState._money(lineTotal)} ₺',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: SifaBrand.deepGold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final product = selected;
            final quantity =
                double.tryParse(qty.text.replaceAll(',', '.'));
            final unitPrice =
                double.tryParse(price.text.replaceAll(',', '.'));

            if (product == null ||
                quantity == null ||
                quantity <= 0 ||
                unitPrice == null ||
                unitPrice < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Malzeme, miktar ve geçerli fiyat gir.'),
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              _SaleLine(
                product: product,
                quantity: quantity,
                unitPrice: unitPrice,
              ),
            );
          },
          child: Text(widget.initial == null ? 'Ekle' : 'Kaydet'),
        ),
      ],
    );
  }
}

class _SalesMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;

  const _SalesMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: emphasize ? SifaBrand.goldBg : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize
              ? SifaBrand.gold.withOpacity(0.35)
              : SifaBrand.softGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: emphasize ? SifaBrand.deepGold : SifaBrand.textGrey,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: emphasize
                    ? SifaBrand.deepGold
                    : SifaBrand.charcoal,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 2),
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

class _SaleLine {
  final Product product;
  final double quantity;
  final double unitPrice;

  const _SaleLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });
}

class _SaleDraft {
  final DateTime date;
  final String? note;
  final List<_SaleLine> lines;

  const _SaleDraft({
    required this.date,
    required this.note,
    required this.lines,
  });
}
