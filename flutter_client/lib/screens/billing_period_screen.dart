import 'package:flutter/material.dart';

import '../services/offline_billing_repository.dart';

class BillingPeriodScreen extends StatefulWidget {
  final String rentalId;
  final DateTime renewalDate;

  const BillingPeriodScreen({
    super.key,
    required this.rentalId,
    required this.renewalDate,
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
    if (period == null) return;

    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tahsilat Gir'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Toplam tahsil edilen (₺)',
            border: OutlineInputBorder(),
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
              if (value != null && value >= 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (amount == null) return;

    try {
      final updated = await repo.recordPayment(
        rentalId: widget.rentalId,
        renewalDate: widget.renewalDate,
        paidAmount: amount,
      );

      if (mounted) {
        setState(() => period = updated);
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
        appBar: AppBar(title: const Text('Kira Dönemi')),
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
    final balance = (billed - paid).clamp(0, double.infinity);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kira Dönemi'),
        actions: [
          if (p['pending_sync'] == true)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Chip(
                label: Text('Senkron bekliyor'),
                avatar: Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${billed.toStringAsFixed(2)} ₺',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Text(
                      'Bu dönemin sabitlenmiş kira tutarı',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tahsil edilen: '
                      '${paid.toStringAsFixed(2)} ₺',
                    ),
                    Text(
                      'Kalan: ${balance.toStringAsFixed(2)} ₺',
                    ),
                    Text('Ödeme: ${p['payment_status']}'),
                    Text('Fatura: ${p['invoice_status']}'),
                    Text(
                      'Vade: '
                      '${dueDate == null ? "Girilmedi" : _date(dueDate)}',
                      style: TextStyle(
                        fontWeight: overdue
                            ? FontWeight.w900
                            : FontWeight.normal,
                      ),
                    ),
                    if (overdue)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Chip(
                          avatar: Icon(
                            Icons.warning_amber_outlined,
                            size: 18,
                          ),
                          label: Text('VADESİ GEÇMİŞ'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...snapshot.map(
              (raw) {
                final line =
                    Map<String, dynamic>.from(raw as Map);
                return Card(
                  child: ListTile(
                    title: Text(
                      line['product_name']?.toString() ??
                          'Malzeme',
                    ),
                    subtitle: Text(
                      '${line['remaining_quantity']} '
                      '${line['unit']} • '
                      'Fiyat: ${line['rate_amount'] ?? "Yok"}',
                    ),
                    trailing: Text(
                      '${((line['line_amount'] as num?) ?? 0).toDouble().toStringAsFixed(2)} ₺',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _payment,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Tahsilat Gir'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      p['invoice_status'] == 'not_required'
                          ? null
                          : _invoice,
                  icon:
                      const Icon(Icons.receipt_long_outlined),
                  label: Text(
                    p['invoice_status'] == 'issued'
                        ? 'Fatura Bilgisi'
                        : 'Fatura Kesildi',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      p['invoice_status'] == 'issued'
                          ? _editDueDate
                          : null,
                  icon: const Icon(
                    Icons.event_available_outlined,
                  ),
                  label: const Text('Ödeme Vadesi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.'
      '${value.year}';
}
