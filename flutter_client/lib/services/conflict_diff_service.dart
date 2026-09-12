import 'dart:convert';

import '../database/local_database.dart';

class ConflictFieldDiff {
  final String key;
  final String label;
  final String localValue;
  final String serverValue;
  final bool different;

  const ConflictFieldDiff({
    required this.key,
    required this.label,
    required this.localValue,
    required this.serverValue,
    required this.different,
  });
}

class ConflictDiffService {
  List<ConflictFieldDiff> build(SyncConflict conflict) {
    final local = _asMap(_decode(conflict.localPayloadJson));
    final serverEnvelope = conflict.serverPayloadJson == null
        ? <String, dynamic>{}
        : _asMap(_decode(conflict.serverPayloadJson!));

    final detail = _asMap(serverEnvelope['detail']);
    final server = _asMap(
      detail['current_record'] ?? serverEnvelope['current_record'],
    );

    final keys = _keysFor(conflict.operationType, local);
    return keys.map((key) {
      final localRaw = local[key];
      final serverRaw = server[key];

      return ConflictFieldDiff(
        key: key,
        label: _label(key),
        localValue: _format(key, localRaw),
        serverValue: _format(key, serverRaw),
        different: _normalize(localRaw) != _normalize(serverRaw),
      );
    }).toList();
  }

  List<String> _keysFor(
    String operationType,
    Map<String, dynamic> local,
  ) {
    if (operationType == 'changeInvoicePreference') {
      return ['invoice_preference'];
    }

    if (operationType == 'updateBillingPeriod') {
      const ordered = [
        'invoice_status',
        'invoice_date',
        'invoice_no',
        'billed_amount',
        'payment_status',
        'paid_amount',
      ];
      return ordered.where(local.containsKey).toList();
    }

    const ignored = {
      'client_operation_id',
      'expected_version',
      'rental_record_id',
      'period_id',
      'id',
    };
    return local.keys.where((k) => !ignored.contains(k)).toList();
  }

  String _label(String key) => switch (key) {
        'invoice_preference' => 'Fatura Tercihi',
        'invoice_status' => 'Fatura Durumu',
        'invoice_date' => 'Fatura Tarihi',
        'invoice_no' => 'Fatura No',
        'billed_amount' => 'Fatura Tutarı',
        'payment_status' => 'Tahsilat Durumu',
        'paid_amount' => 'Tahsil Edilen',
        'renewal_date' => 'Kira Dönemi',
        'note' => 'Not',
        _ => key,
      };

  String _format(String key, dynamic value) {
    if (value == null) return 'Boş';

    if (key == 'invoice_preference') {
      return value == 'invoice_required' ? 'Faturalı' : 'Faturasız';
    }

    if (key == 'invoice_status') {
      return switch (value.toString()) {
        'issued' => 'Fatura kesildi',
        'pending' => 'Fatura bekliyor',
        'not_required' => 'Fatura gerekmiyor',
        _ => value.toString(),
      };
    }

    if (key == 'payment_status') {
      return switch (value.toString()) {
        'paid' => 'Ödendi',
        'partial' => 'Kısmi ödeme',
        'pending' => 'Bekliyor',
        _ => value.toString(),
      };
    }

    if (key == 'billed_amount' || key == 'paid_amount') {
      final n = value is num
          ? value.toDouble()
          : double.tryParse(value.toString());
      if (n != null) return '${_money(n)} ₺';
    }

    return value.toString();
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < chars.length; i += 3) {
      groups.add(
        chars.skip(i).take(3).toList().reversed.join(),
      );
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00'
        ? whole
        : '$whole,${parts[1]}';
  }

  dynamic _decode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  String _normalize(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toDouble().toStringAsFixed(4);
    return value.toString().trim().toLowerCase();
  }
}
