import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'local_domain_cache.dart';
import 'offline_sync_service.dart';

class OfflineBillingRepository {
  OfflineBillingRepository({ApiClient? api, LocalDomainCache? cache, OfflineSyncService? queue})
      : api = api ?? ApiClient(),
        cache = cache ?? LocalDomainCache(),
        queue = queue ?? OfflineSyncService();

  final ApiClient api;
  final LocalDomainCache cache;
  final OfflineSyncService queue;
  final uuid = const Uuid();

  Future<Map<String, dynamic>> getOrCreate(String rentalId, DateTime renewalDate) async {
    final operationId = uuid.v4();
    final local = await cache.billingPeriodByDate(rentalId, renewalDate);
    if (ApiConfig.configured) {
      try {
        final data = await api.postJson('/rentals/$rentalId/billing-periods', {
          'renewal_date': _date(renewalDate),
          'client_operation_id': operationId,
        });
        final row = Map<String,dynamic>.from(data as Map);
        await _cacheServer(row, rentalId);
        return row;
      } catch (_) {}
    }
    if (local != null) return _mapLocal(local);

    final detail = await _localCalculation(rentalId, renewalDate);
    final localId = 'local_${rentalId}_${_date(renewalDate)}';
    await cache.upsertBillingPeriod(
      id: localId,
      rentalId: rentalId,
      renewalDate: renewalDate,
      invoiceStatus: detail['invoice_status'].toString(),
      paymentStatus: 'pending',
      billedAmount: (detail['billed_amount'] as num).toDouble(),
      paidAmount: 0,
      snapshotJson: jsonEncode(detail['quantity_rate_snapshot']),
      pendingSync: true,
      rowVersion: 1,
    );
    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createBillingPeriod,
      {
        'rental_record_id': rentalId,
        'renewal_date': renewalDate.toIso8601String(),
      },
    );
    return {
      'id': localId,
      'rental_record_id': rentalId,
      'renewal_date': renewalDate.toIso8601String(),
      ...detail,
      'payment_status': 'pending',
      'paid_amount': 0.0,
      'row_version': 1,
      'pending_sync': true,
    };
  }

  Future<Map<String, dynamic>> markInvoiceIssued({
    required String rentalId,
    required DateTime renewalDate,
    String? invoiceNo,
    DateTime? invoiceDate,
    DateTime? paymentDueDate,
  }) async {
    final current = await getOrCreate(rentalId, renewalDate);
    return _update(
      current: current,
      rentalId: rentalId,
      renewalDate: renewalDate,
      invoiceStatus: 'issued',
      invoiceDate: invoiceDate ?? DateTime.now(),
      invoiceNo: invoiceNo,
      paymentDueDate: paymentDueDate,
      paymentDueDateSpecified: true,
    );
  }


Future<Map<String, dynamic>> setPaymentDueDate({
  required String rentalId,
  required DateTime renewalDate,
  DateTime? paymentDueDate,
}) async {
  final current = await getOrCreate(
    rentalId,
    renewalDate,
  );

  if (current['invoice_status'] != 'issued') {
    throw StateError(
      'Ödeme vadesi yalnız kesilmiş faturaya girilebilir.',
    );
  }

  return _update(
    current: current,
    rentalId: rentalId,
    renewalDate: renewalDate,
    paymentDueDate: paymentDueDate,
    paymentDueDateSpecified: true,
  );
}

  Future<Map<String, dynamic>> recordPayment({
    required String rentalId,
    required DateTime renewalDate,
    required double paidAmount,
  }) async {
    final current = await getOrCreate(rentalId, renewalDate);
    final billed = ((current['billed_amount'] as num?) ?? 0).toDouble();
    final status = paidAmount <= 0 ? 'pending' : paidAmount >= billed ? 'paid' : 'partial';
    return _update(
      current: current,
      rentalId: rentalId,
      renewalDate: renewalDate,
      paymentStatus: status,
      paidAmount: paidAmount,
    );
  }

  Future<Map<String,dynamic>> _update({
    required Map<String,dynamic> current,
    required String rentalId,
    required DateTime renewalDate,
    String? invoiceStatus,
    DateTime? invoiceDate,
    String? invoiceNo,
    DateTime? paymentDueDate,
    bool paymentDueDateSpecified = false,
    String? paymentStatus,
    double? paidAmount,
  }) async {
    final operationId = uuid.v4();
    final expectedVersion = (current['row_version'] as num?)?.toInt() ?? 1;
    final next = {
      ...current,
      if (invoiceStatus != null) 'invoice_status': invoiceStatus,
      if (invoiceDate != null) 'invoice_date': invoiceDate.toIso8601String(),
      if (invoiceNo != null) 'invoice_no': invoiceNo,
      if (paymentDueDateSpecified)
        'payment_due_date': paymentDueDate?.toIso8601String(),
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paidAmount != null) 'paid_amount': paidAmount,
      'row_version': expectedVersion + 1,
      'pending_sync': true,
    };
    await cache.upsertBillingPeriod(
      id: current['id'].toString(), rentalId: rentalId, renewalDate: renewalDate,
      invoiceStatus: next['invoice_status'].toString(),
      paymentStatus: next['payment_status'].toString(),
      billedAmount: (next['billed_amount'] as num?)?.toDouble(),
      paidAmount: (next['paid_amount'] as num?)?.toDouble(),
      invoiceNo: next['invoice_no']?.toString(),
      invoiceDate: next['invoice_date'] == null
          ? null
          : DateTime.parse(next['invoice_date'].toString()),
      paymentDueDate: next['payment_due_date'] == null
          ? null
          : DateTime.parse(next['payment_due_date'].toString()),
      snapshotJson: jsonEncode(next['quantity_rate_snapshot'] ?? const []),
      pendingSync: true, rowVersion: expectedVersion + 1,
    );
    final payload = {
      'rental_record_id': rentalId,
      'renewal_date': renewalDate.toIso8601String(),
      if (invoiceStatus != null) 'invoice_status': invoiceStatus,
      if (invoiceDate != null) 'invoice_date': _date(invoiceDate),
      if (invoiceNo != null) 'invoice_no': invoiceNo,
      if (paymentDueDateSpecified)
        'payment_due_date':
            paymentDueDate == null ? null : _date(paymentDueDate),
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paidAmount != null) 'paid_amount': paidAmount,
      'expected_version': expectedVersion,
    };
    if (ApiConfig.configured) {
      try {
        final data = await api.patchJson(
          '/rentals/$rentalId/billing-periods/by-date/${_date(renewalDate)}',
          {...payload, 'client_operation_id': operationId},
        );
        final row=Map<String,dynamic>.from(data as Map);
        await _cacheServer(row,rentalId);
        return row;
      } catch (_) {}
    }
    await queue.enqueueWithId(
      operationId,
      SyncOperationType.updateBillingPeriod,
      payload,
    );
    return next;
  }

  Future<Map<String,dynamic>> _localCalculation(String rentalId, DateTime renewalDate) async {
    final rental=await cache.rental(rentalId);
    if(rental==null) throw StateError('Kiralama cihazda bulunamadı.');
    final items=await cache.rentalItems(rentalId);
    final movements=await cache.movements(rentalId);
    final rates=await cache.rates(rentalId);
    final products={for(final p in await cache.products()) p.id:p};
    final snapshot=<Map<String,dynamic>>[];
    double total=0;
    for(final item in items){
      final returned=movements.where((m)=>m.rentalItemId==item.id && m.movementType=='inbound_return' && !m.movementDate.isAfter(renewalDate)).fold<double>(0,(s,m)=>s+m.quantity);
      final remaining=(item.initialQuantity-returned).clamp(0,double.infinity).toDouble();
      final applicable=rates.where((r)=>r.rentalItemId==item.id && !r.effectiveFrom.isAfter(renewalDate)).toList()..sort((a,b)=>b.effectiveFrom.compareTo(a.effectiveFrom));
      final rate=applicable.isEmpty?null:applicable.first;
      final line=rate==null?0.0:(rate.rateType=='fixed_monthly'?(remaining>0?rate.amount:0):remaining*rate.amount);
      total+=line;
      snapshot.add({
        'rental_item_id':item.id,'product_id':item.productId,
        'product_name':products[item.productId]?.name ?? item.productId,
        'unit':products[item.productId]?.unit ?? 'piece',
        'remaining_quantity':remaining,'rate_amount':rate?.amount,
        'rate_type':rate?.rateType,'rate_effective_from':rate?.effectiveFrom.toIso8601String(),
        'line_amount':line,
      });
    }
    return {
      'invoice_status':rental.invoicePreference=='invoice_required'?'pending':'not_required',
      'billed_amount':total,'quantity_rate_snapshot':snapshot,
    };
  }

  Future<void> _cacheServer(Map<String,dynamic> row,String rentalId) async {
    await cache.upsertBillingPeriod(
      id:row['id'].toString(), rentalId:rentalId,
      renewalDate:DateTime.parse(row['renewal_date'].toString()),
      invoiceStatus:row['invoice_status']?.toString() ?? 'not_required',
      paymentStatus:row['payment_status']?.toString() ?? 'pending',
      billedAmount:(row['billed_amount'] as num?)?.toDouble(),
      paidAmount:(row['paid_amount'] as num?)?.toDouble(),
      invoiceNo:row['invoice_no']?.toString(),
      invoiceDate: row['invoice_date'] == null
          ? null
          : DateTime.parse(row['invoice_date'].toString()),
      paymentDueDate: row['payment_due_date'] == null
          ? null
          : DateTime.parse(row['payment_due_date'].toString()),
      snapshotJson:jsonEncode(row['quantity_rate_snapshot'] ?? const []),
      pendingSync:false,rowVersion:(row['row_version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String,dynamic> _mapLocal(dynamic p)=>{
    'id':p.id,'rental_record_id':p.rentalId,'renewal_date':p.renewalDate.toIso8601String(),
    'invoice_status':p.invoiceStatus,'payment_status':p.paymentStatus,
    'billed_amount':p.billedAmount,'paid_amount':p.paidAmount,
    'invoice_no':p.invoiceNo,
    'invoice_date':p.invoiceDate?.toIso8601String(),
    'payment_due_date':p.paymentDueDate?.toIso8601String(),
    'quantity_rate_snapshot':p.snapshotJson==null?const []:jsonDecode(p.snapshotJson!),
    'row_version':p.rowVersion,'pending_sync':p.pendingSync,
  };

  String _date(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
