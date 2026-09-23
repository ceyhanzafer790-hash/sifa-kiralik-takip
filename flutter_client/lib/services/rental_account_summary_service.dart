import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rental_date_service.dart';

class RentalAccountSummaryService {
  const RentalAccountSummaryService();

  String buildWhatsAppText(Map<String, dynamic> detail) {
    final rental = Map<String, dynamic>.from(detail['rental'] as Map);
    final items = _maps(detail['items']);
    final rates = _maps(detail['rates']);
    final billing = _maps(detail['billing_periods']);

    final buffer = StringBuffer()
      ..writeln('ŞİFA İNŞAAT')
      ..writeln('MÜŞTERİ ÖZETİ')
      ..writeln()
      ..writeln('Müşteri: ${rental['customer_name'] ?? 'Müşteri'}');

    if (rental['address_label'] != null) {
      buffer.writeln('Şantiye: ${rental['address_label']}');
    }

    final original = DateTime.tryParse(
      rental['original_outbound_date']?.toString() ?? '',
    );
    if (original != null) {
      buffer.writeln('Başlangıç: ${trDate(original)}');
    }

    buffer.writeln();

    for (final item in items) {
      final initial = _double(item['initial_quantity']);
      final returned = _double(item['returned_quantity']);
      final remaining =
          (initial - returned).clamp(0.0, double.infinity).toDouble();
      final currentRate = _currentRate(item, rates);

      buffer
        ..writeln(item['product_name']?.toString() ?? 'Malzeme')
        ..writeln('Gönderilen: ${_number(initial)} ${_unit(item['unit'])}')
        ..writeln('İade: ${_number(returned)} ${_unit(item['unit'])}')
        ..writeln('Müşteride: ${_number(remaining)} ${_unit(item['unit'])}');

      if (currentRate != null) {
        final rateLabel = currentRate['rate_type'] == 'fixed_monthly'
            ? 'sabit aylık'
            : 'birim başına aylık';
        buffer.writeln(
          'Güncel fiyat: ${_money(_double(currentRate['amount']))} ₺ ($rateLabel)',
        );
      }

      buffer.writeln();
    }

    final totals = billingTotals(billing);
    if (totals.billed > 0 || totals.paid > 0) {
      buffer
        ..writeln('Hesap Durumu')
        ..writeln('Faturalandırılmış: ${_money(totals.billed)} ₺')
        ..writeln('Tahsil Edilen: ${_money(totals.paid)} ₺')
        ..writeln('Kalan: ${_money(totals.balance)} ₺')
        ..writeln();
    }

    buffer.writeln('ŞİFA İnşaat • Güçlü Yapılar, Güvenilir Ortaklıklar.');
    return buffer.toString().trim();
  }

  Future<bool> shareWhatsApp(Map<String, dynamic> detail) async {
    final summary = buildWhatsAppText(detail);
    final native = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(summary)}',
    );

    if (await canLaunchUrl(native)) {
      final opened = await launchUrl(
        native,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    }

    return launchUrl(
      Uri.https('wa.me', '/', {'text': summary}),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<Uint8List> buildPdf(Map<String, dynamic> detail) async {
    final rental = Map<String, dynamic>.from(detail['rental'] as Map);
    final items = _maps(detail['items']);
    final rates = _maps(detail['rates']);
    final billing = _maps(detail['billing_periods']);
    final totals = billingTotals(billing);

    final document = pw.Document(
      title: 'Sifa Insaat - Kiralama Hesap Ozeti',
      author: 'Sifa Insaat',
      creator: 'Sifa Kiralik Takip',
    );

    final original = DateTime.tryParse(
      rental['original_outbound_date']?.toString() ?? '',
    );

    final navy = PdfColor.fromHex('#111111');
    final warm = PdfColor.fromHex('#D4AF37');
    final soft = PdfColor.fromHex('#FAFAF8');
    final border = PdfColor.fromHex('#E5E5E5');

    final rows = <List<String>>[];
    for (final item in items) {
      final initial = _double(item['initial_quantity']);
      final returned = _double(item['returned_quantity']);
      final remaining =
          (initial - returned).clamp(0.0, double.infinity).toDouble();
      final currentRate = _currentRate(item, rates);

      rows.add([
        _pdfText(item['product_name']?.toString() ?? 'Malzeme'),
        '${_number(initial)} ${_pdfText(_unit(item['unit']))}',
        '${_number(returned)} ${_pdfText(_unit(item['unit']))}',
        '${_number(remaining)} ${_pdfText(_unit(item['unit']))}',
        currentRate == null
            ? '-'
            : '${_money(_double(currentRate['amount']))} TL',
      ]);
    }

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(34),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          margin: const pw.EdgeInsets.only(bottom: 18),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: warm, width: 1.6),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SIFA',
                      style: pw.TextStyle(
                        color: navy,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Text(
                      'INSAAT  •  KIRALIK TAKIP',
                      style: pw.TextStyle(
                        color: warm,
                        fontSize: 8,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                'MUSTERI EKSTRESI',
                style: pw.TextStyle(
                  color: navy,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Sifa Insaat  •  Guclu Yapilar, Guvenilir Ortakliklar.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Sayfa ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: soft,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfInfo(
                  'Musteri',
                  _pdfText(rental['customer_name']?.toString() ?? 'Musteri'),
                  navy,
                ),
                if (rental['address_label'] != null)
                  _pdfInfo(
                    'Santiye',
                    _pdfText(rental['address_label'].toString()),
                    navy,
                  ),
                if (original != null)
                  _pdfInfo('Baslangic', trDate(original), navy),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Malzeme Durumu',
            style: pw.TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _pdfTable(
            headers: const [
              'Malzeme',
              'Gonderilen',
              'Iade',
              'Musteride',
              'Guncel Fiyat',
            ],
            rows: rows,
            navy: navy,
            border: border,
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Hesap Durumu',
            style: pw.TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _pdfMoneyCard('Faturalandirilan', totals.billed, soft, navy),
              pw.SizedBox(width: 8),
              _pdfMoneyCard('Tahsil Edilen', totals.paid, soft, navy),
              pw.SizedBox(width: 8),
              _pdfMoneyCard('Kalan', totals.balance, soft, navy),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Bu ozet uygulamadaki guncel kiralama, iade ve tahsilat kayitlarindan uretilmistir.',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<ShareResult> sharePdf(
    BuildContext context,
    Map<String, dynamic> detail,
  ) async {
    final bytes = await buildPdf(detail);
    final rental = Map<String, dynamic>.from(detail['rental'] as Map);
    final customer = _safeFileName(
      rental['customer_name']?.toString() ?? 'musteri',
    );
    final fileName = 'sifa_kiralama_ozeti_$customer.pdf';

    Rect? shareOrigin;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      shareOrigin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }

    return SharePlus.instance.share(
      ShareParams(
        text: 'Şifa İnşaat kiralama hesap özeti',
        subject: 'Kiralama Hesap Özeti',
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
          ),
        ],
        fileNameOverrides: [fileName],
        sharePositionOrigin: shareOrigin,
        downloadFallbackEnabled: true,
      ),
    );
  }

  AccountTotals billingTotals(List<Map<String, dynamic>> billing) {
    final billed = billing.fold<double>(
      0,
      (sum, row) => sum + _double(row['billed_amount']),
    );
    final paid = billing.fold<double>(
      0,
      (sum, row) => sum + _double(row['paid_amount']),
    );
    return AccountTotals(
      billed: billed,
      paid: paid,
      balance: (billed - paid).clamp(0.0, double.infinity).toDouble(),
    );
  }

  static pw.Widget _pdfInfo(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 88,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> rows,
    required PdfColor navy,
    required PdfColor border,
  }) {
    final allRows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: navy),
        children: headers
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...rows.map(
        (row) => pw.TableRow(
          children: row
              .map(
                (cell) => pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Text(
                    cell,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
      },
      children: allRows,
    );
  }

  static pw.Widget _pdfMoneyCard(
    String title,
    double amount,
    PdfColor background,
    PdfColor foreground,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${_money(amount)} TL',
              style: pw.TextStyle(
                fontSize: 13,
                color: foreground,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      ((value as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  static Map<String, dynamic>? _currentRate(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> rates,
  ) {
    final itemRates = rates
        .where(
          (r) => r['rental_item_id'].toString() == item['id'].toString(),
        )
        .toList()
      ..sort(
        (a, b) => DateTime.parse(b['effective_from'].toString())
            .compareTo(DateTime.parse(a['effective_from'].toString())),
      );
    return itemRates.isEmpty ? null : itemRates.first;
  }

  static double _double(dynamic value) => (value as num?)?.toDouble() ?? 0;

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

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

  static String _unit(dynamic unit) => switch (unit?.toString()) {
        'sheet' => 'Levha',
        'meter' => 'Metre',
        'squareMeter' || 'square_meter' => 'm²',
        'cubicMeter' || 'cubic_meter' => 'm³',
        'kilogram' => 'kg',
        'liter' => 'Litre',
        'set' => 'Takım',
        _ => 'Adet',
      };

  static String _safeFileName(String value) {
    final ascii = _pdfText(value).toLowerCase();
    return ascii
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _pdfText(String value) {
    const map = {
      'ş': 's',
      'Ş': 'S',
      'ğ': 'g',
      'Ğ': 'G',
      'ü': 'u',
      'Ü': 'U',
      'ö': 'o',
      'Ö': 'O',
      'ç': 'c',
      'Ç': 'C',
      'ı': 'i',
      'İ': 'I',
    };

    var result = value;
    map.forEach((source, target) {
      result = result.replaceAll(source, target);
    });
    return result;
  }
}

class AccountTotals {
  final double billed;
  final double paid;
  final double balance;

  const AccountTotals({
    required this.billed,
    required this.paid,
    required this.balance,
  });
}
