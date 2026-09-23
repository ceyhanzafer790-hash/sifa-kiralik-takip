import 'package:flutter/material.dart';

import '../services/offline_billing_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

class BillingPeriodScreen extends StatefulWidget {
  final String rentalId;
  final DateTime renewalDate;
  final bool paymentFocus;

  const BillingPeriodScreen({
    super.key,
    required this.rentalId,
    required this.renewalDate,
    this.paymentFocus = false,
  });

  @override
  State<BillingPeriodScreen> createState() =>
      _BillingPeriodScreenState();
}

class _BillingPeriodScreenState
    extends State<BillingPeriodScreen> {
  final repo = OfflineBillingRepository();

  Map<String, dynamic>? period;
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
      final result = await repo.getOrCreate(
        widget.rentalId,
        widget.renewalDate,
      );

      if (mounted) {
        setState(() => period = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _invoice() async {
    final current = period;
    if (current == null) return;

    final invoiceNoController = TextEditingController(
      text: current['invoice_no']?.toString() ?? '',
    );

    final existingInvoiceDate = current['invoice_date'] == null
        ? null
        : DateTime.tryParse(
            current['invoice_date'].toString(),
          );

    DateTime invoiceDate =
        existingInvoiceDate ?? DateTime.now();

    DateTime? dueDate = current['payment_due_date'] == null
        ? null
        : DateTime.tryParse(
            current['payment_due_date'].toString(),
          );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            current['invoice_status'] == 'issued'
                ? 'Fatura Bilgisi'
                : 'Fatura Kesildi',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: invoiceNoController,
                decoration: const InputDecoration(
                  labelText: 'Fatura no',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_outlined),
                title: const Text('Fatura tarihi'),
                subtitle: Text(_date(invoiceDate)),
                trailing: IconButton(
                  tooltip: 'Fatura tarihi seç',
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: invoiceDate,
                    );

                    if (picked == null) return;

                    setDialogState(() {
                      invoiceDate = picked;
                      if (dueDate != null &&
                          dueDate!.isBefore(invoiceDate)) {
                        dueDate = null;
                      }
                    });
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.event_available_outlined,
                ),
                title: const Text('Ödeme vadesi'),
                subtitle: Text(
                  dueDate == null
                      ? 'Vade girilmedi'
                      : _date(dueDate!),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (dueDate != null)
                      IconButton(
                        tooltip: 'Vadeyi kaldır',
                        onPressed: () {
                          setDialogState(() => dueDate = null);
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Vade seç',
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: invoiceDate,
                          lastDate: DateTime(
                            invoiceDate.year + 5,
                            12,
                            31,
                          ),
                          initialDate: (
                            dueDate != null &&
                                    !dueDate!.isBefore(invoiceDate)
                                ? dueDate!
                                : invoiceDate
                          ),
                        );

                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Vade boş bırakılırsa fatura açık alacakta görünür '
                'ama “vadesi geçmiş” sayılmaz.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                {
                  'invoice_no': invoiceNoController.text.trim(),
                  'invoice_date': invoiceDate,
                  'payment_due_date': dueDate,
                },
              ),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    invoiceNoController.dispose();
    if (result == null) return;

    try {
      final updated = await repo.markInvoiceIssued(
        rentalId: widget.rentalId,
        renewalDate: widget.renewalDate,
        invoiceNo:
            (result['invoice_no'] as String).isEmpty
                ? null
                : result['invoice_no'] as String,
        invoiceDate: result['invoice_date'] as DateTime,
        paymentDueDate:
            result['payment_due_date'] as DateTime?,
      );

      if (mounted) {
        setState(() => period = updated);
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editDueDate() async {
    final current = period;
    if (current == null) return;

    if (current['invoice_status'] != 'issued') {
      _showError(
        'Ödeme vadesi için önce faturanın kesilmiş olması gerekir.',
      );
      return;
    }

    final raw = current['payment_due_date'];
    final existing = raw == null
        ? null
        : DateTime.tryParse(raw.toString());

    final invoiceRaw = current['invoice_date'];
    final invoiceDate = invoiceRaw == null
        ? DateTime.now()
        : DateTime.tryParse(invoiceRaw.toString()) ?? DateTime.now();

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Vade tarihi seç'),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (existing != null)
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Vadeyi kaldır'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
          ],
        ),
      ),
    );

    if (action == null) return;

    DateTime? nextDueDate;

    if (action == 'pick') {
      nextDueDate = await showDatePicker(
        context: context,
        firstDate: DateTime(
          invoiceDate.year,
          invoiceDate.month,
          invoiceDate.day,
        ),
        lastDate: DateTime(
          invoiceDate.year + 5,
          12,
          31,
        ),
        initialDate: existing ?? invoiceDate,
      );

      if (nextDueDate == null) return;
    }

    try {
      final updated = await repo.setPaymentDueDate(
        rentalId: widget.rentalId,
        renewalDate: widget.renewalDate,
        paymentDueDate: nextDueDate,
      );

      if (mounted) {
        setState(() => period = updated);
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _payment() async {
    final current = period;
    if (current == null) return;

    final billed = ((current['billed_amount'] as num?) ?? 0).toDouble();
    final alreadyPaid =
        ((current['paid_amount'] as num?) ?? 0).toDouble();
    final remaining =
        (billed - alreadyPaid).clamp(0.0, double.infinity).toDouble();

    if (remaining <= 0) {
      _showMessage('Bu dönem için açık bakiye kalmadı.');
      return;
    }

    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tahsilat Gir'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SifaBrand.goldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: SifaBrand.deepGold,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kalan bakiye',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_money(remaining)} ₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Bu işlemde alınan tutar',
                    suffixText: '₺',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      controller.text = _plainNumber(remaining);
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Kalanın Tamamı'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mevcut tahsilat: ${_money(alreadyPaid)} ₺. '
                  'Girdiğin tutar buna eklenecek.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SifaBrand.textGrey,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                if (value == null || value <= 0 || value > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '0 ile ${_money(remaining)} ₺ arasında bir tutar gir.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Tahsilatı Kaydet'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (amount == null) return;

    try {
      final updated = await repo.recordPayment(
        rentalId: widget.rentalId,
        renewalDate: widget.renewalDate,
        paidAmount: alreadyPaid + amount,
      );

      if (mounted) {
        setState(() => period = updated);
        _showMessage('Tahsilat kaydedildi.');
      }
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && period == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (period == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.paymentFocus ? 'Tahsilat' : 'Kira Dönemi',
          ),
        ),
        body: Center(
          child: Text(error ?? 'Dönem açılamadı.'),
        ),
      );
    }

    final p = period!;
    final billed =
        ((p['billed_amount'] as num?) ?? 0).toDouble();
    final paid =
        ((p['paid_amount'] as num?) ?? 0).toDouble();
    final balance =
        (billed - paid).clamp(0.0, double.infinity).toDouble();
    final snapshot =
        (p['quantity_rate_snapshot'] as List?) ?? const [];

    final dueRaw = p['payment_due_date'];
    final dueDate = dueRaw == null
        ? null
        : DateTime.tryParse(dueRaw.toString());

    final today = DateTime.now();
    final overdue = dueDate != null &&
        balance > 0 &&
        DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        ).isBefore(
          DateTime(today.year, today.month, today.day),
        );

    final paymentStatus =
        p['payment_status']?.toString() ?? 'pending';
    final invoiceStatus =
        p['invoice_status']?.toString() ?? 'not_required';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.paymentFocus ? 'Tahsilat' : 'Kira Dönemi',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: SifaBrand.gold,
          ),
        ),
        actions: [
          if (p['pending_sync'] == true)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Center(
                child: StatusPill(
                  label: 'Senkron bekliyor',
                  tone: AppStatusTone.info,
                  icon: Icons.cloud_upload_outlined,
                  compact: true,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (widget.paymentFocus) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SifaBrand.goldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SifaBrand.gold.withOpacity(0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: SifaBrand.deepGold,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Bu dönemde aldığın yeni tahsilatı gir.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                        const Expanded(
                          child: Text(
                            'Dönem Hesabı',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        Text(
                          _date(widget.renewalDate),
                          style: const TextStyle(
                            color: SifaBrand.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        Expanded(
                          child: _BillingMetric(
                            label: 'Fatura',
                            amount: billed,
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BillingMetric(
                            label: 'Tahsil',
                            amount: paid,
                            icon: Icons.payments_outlined,
                            tone: SifaBrand.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BillingMetric(
                            label: 'Kalan',
                            amount: balance,
                            icon: Icons.account_balance_wallet_outlined,
                            emphasize: balance > 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                StatusPill(
                  label: _paymentLabel(paymentStatus),
                  tone: _paymentTone(paymentStatus),
                  icon: Icons.payments_outlined,
                  compact: true,
                ),
                StatusPill(
                  label: _invoiceLabel(invoiceStatus),
                  tone: invoiceStatus == 'issued'
                      ? AppStatusTone.success
                      : AppStatusTone.neutral,
                  icon: Icons.receipt_long_outlined,
                  compact: true,
                ),
                StatusPill(
                  label: dueDate == null
                      ? 'Vade girilmedi'
                      : 'Vade ${_date(dueDate)}',
                  tone: overdue
                      ? AppStatusTone.danger
                      : AppStatusTone.neutral,
                  icon: overdue
                      ? Icons.warning_amber_outlined
                      : Icons.event_available_outlined,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: balance > 0 ? _payment : null,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  balance > 0
                      ? 'Tahsilat Gir'
                      : 'Bu Dönem Ödendi',
                ),
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      invoiceStatus == 'not_required'
                          ? null
                          : _invoice,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(
                    invoiceStatus == 'issued'
                        ? 'Fatura Bilgisi'
                        : 'Fatura Kesildi',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      invoiceStatus == 'issued'
                          ? _editDueDate
                          : null,
                  icon: const Icon(
                    Icons.event_available_outlined,
                  ),
                  label: const Text('Ödeme Vadesi'),
                ),
              ],
            ),
            if (!widget.paymentFocus) ...[
              const SizedBox(height: 22),
              Text(
                'Dönem Kalemleri',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 9),
              ...snapshot.map(
                (raw) {
                  final line =
                      Map<String, dynamic>.from(raw as Map);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: SifaBrand.gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: SifaBrand.deepGold,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          line['product_name']?.toString() ??
                              'Malzeme',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          '${line['remaining_quantity']} '
                          '${line['unit']} • '
                          'Fiyat: ${line['rate_amount'] ?? "Yok"}',
                        ),
                        trailing: Text(
                          '${_money(((line['line_amount'] as num?) ?? 0).toDouble())} ₺',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  String _paymentLabel(String value) => switch (value) {
        'paid' => 'Ödendi',
        'partial' => 'Kısmi tahsil',
        _ => 'Bekliyor',
      };

  AppStatusTone _paymentTone(String value) => switch (value) {
        'paid' => AppStatusTone.success,
        'partial' => AppStatusTone.warning,
        _ => AppStatusTone.danger,
      };

  String _invoiceLabel(String value) => switch (value) {
        'issued' => 'Fatura kesildi',
        'pending' => 'Fatura bekliyor',
        _ => 'Faturasız',
      };

  static String _plainNumber(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
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

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.'
      '${value.year}';
}

class _BillingMetric extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color? tone;
  final bool emphasize;

  const _BillingMetric({
    required this.label,
    required this.amount,
    required this.icon,
    this.tone,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = emphasize
        ? const Color(0xFF9A5D00)
        : tone ?? SifaBrand.charcoal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
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
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_moneyValue(amount)} ₺',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
                fontSize: 16,
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

  static String _moneyValue(double value) {
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
}
