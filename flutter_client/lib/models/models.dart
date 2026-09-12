enum ProductCategory {
  plywoodOsb,
  timberH20,
  scaffoldConnection,
  propAdjustment,
  formworkTie,
  elevatorCrane,
  siteMaterials,
}

extension ProductCategoryLabel on ProductCategory {
  String get label => switch (this) {
        ProductCategory.plywoodOsb => 'Plywood & OSB',
        ProductCategory.timberH20 => 'Kereste / H20',
        ProductCategory.scaffoldConnection => 'İskele & Bağlantı',
        ProductCategory.propAdjustment => 'Direk & Ayar',
        ProductCategory.formworkTie => 'Kalıp / Tayrot / Çiroz',
        ProductCategory.elevatorCrane => 'Asansör & Vinç',
        ProductCategory.siteMaterials => 'Şantiye Malzemeleri',
      };
}

enum UnitType { piece, sheet, meter, squareMeter, cubicMeter, kilogram, liter, set }

extension UnitTypeLabel on UnitType {
  String get label => switch (this) {
        UnitType.piece => 'Adet',
        UnitType.sheet => 'Levha',
        UnitType.meter => 'Metre',
        UnitType.squareMeter => 'm²',
        UnitType.cubicMeter => 'm³',
        UnitType.kilogram => 'kg',
        UnitType.liter => 'Litre',
        UnitType.set => 'Takım',
      };
}

enum StockConfidence { unknown, estimated, counted }

extension StockConfidenceLabel on StockConfidence {
  String get label => switch (this) {
        StockConfidence.unknown => 'Bilinmiyor',
        StockConfidence.estimated => 'Tahmini',
        StockConfidence.counted => 'Kesin',
      };
}

enum TradeMode { rental, sale, both }

extension TradeModeLabel on TradeMode {
  String get label => switch (this) {
        TradeMode.rental => 'Kiralık',
        TradeMode.sale => 'Satılık',
        TradeMode.both => 'Kiralık + Satılık',
      };
}

class Product {
  final String id;
  final String name;
  final ProductCategory category;
  final UnitType unit;
  final TradeMode tradeMode;
  final String? variant;
  final double? packSize;
  final StockConfidence stockConfidence;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.tradeMode = TradeMode.both,
    this.variant,
    this.packSize,
    this.stockConfidence = StockConfidence.unknown,
  });

  Product copyWith({
    String? name,
    ProductCategory? category,
    UnitType? unit,
    TradeMode? tradeMode,
    String? variant,
    double? packSize,
    StockConfidence? stockConfidence,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      tradeMode: tradeMode ?? this.tradeMode,
      variant: variant ?? this.variant,
      packSize: packSize ?? this.packSize,
      stockConfidence: stockConfidence ?? this.stockConfidence,
    );
  }
}

class Customer {
  final String id;
  final String name;
  final List<CustomerAddress> addresses;

  const Customer({
    required this.id,
    required this.name,
    this.addresses = const [],
  });
}

class CustomerAddress {
  final String id;
  final String label;
  final String fullAddress;

  const CustomerAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
  });
}

class ShipmentLine {
  final Product product;
  final double quantity;

  const ShipmentLine({required this.product, required this.quantity});
}

class ShipmentDraft {
  final Customer? customer;
  final CustomerAddress? address;
  final DateTime date;
  final String? deliveryNoteNo;
  final List<ShipmentLine> lines;
  final String? note;

  const ShipmentDraft({
    this.customer,
    this.address,
    required this.date,
    this.deliveryNoteNo,
    this.lines = const [],
    this.note,
  });

  ShipmentDraft copyWith({
    Customer? customer,
    CustomerAddress? address,
    DateTime? date,
    String? deliveryNoteNo,
    List<ShipmentLine>? lines,
    String? note,
  }) {
    return ShipmentDraft(
      customer: customer ?? this.customer,
      address: address ?? this.address,
      date: date ?? this.date,
      deliveryNoteNo: deliveryNoteNo ?? this.deliveryNoteNo,
      lines: lines ?? this.lines,
      note: note ?? this.note,
    );
  }
}

enum RentalMovementType { outbound, inboundReturn }

extension RentalMovementTypeLabel on RentalMovementType {
  String get label => switch (this) {
        RentalMovementType.outbound => 'Giden',
        RentalMovementType.inboundReturn => 'Gelen',
      };
}

class RentalMovement {
  final String id;
  final String rentalRecordId;
  final String productId;
  final RentalMovementType type;
  final double quantity;
  final DateTime date;
  final RentalReturnCondition? returnCondition;
  final String? note;

  const RentalMovement({
    required this.id,
    required this.rentalRecordId,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
    this.returnCondition,
    this.note,
  });
}

class RentalItemState {
  final Product product;
  final double initialQuantity;
  final double returnedQuantity;

  const RentalItemState({
    required this.product,
    required this.initialQuantity,
    this.returnedQuantity = 0,
  });

  double get remainingQuantity => initialQuantity - returnedQuantity;

  RentalItemState copyWith({
    double? initialQuantity,
    double? returnedQuantity,
  }) {
    return RentalItemState(
      product: product,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      returnedQuantity: returnedQuantity ?? this.returnedQuantity,
    );
  }
}

class RentalTrackingRecord {
  final String id;
  final Customer customer;
  final CustomerAddress? address;
  final DateTime originalOutboundDate;
  final List<RentalItemState> items;
  final List<RentalMovement> movements;
  final InvoicePreference invoicePreference;
  final List<RentalBillingPeriod> billingPeriods;
  final List<RentalItemRate> itemRates;
  final List<RentalDocument> documents;
  final String? note;

  const RentalTrackingRecord({
    required this.id,
    required this.customer,
    this.address,
    required this.originalOutboundDate,
    required this.items,
    required this.movements,
    this.invoicePreference = InvoicePreference.noInvoice,
    this.billingPeriods = const [],
    this.itemRates = const [],
    this.documents = const [],
    this.note,
  });

  int get rentalDayOfMonth => originalOutboundDate.day;

  bool get isClosed => items.every((e) => e.remainingQuantity <= 0);

  double get totalRemaining =>
      items.fold(0, (sum, item) => sum + item.remainingQuantity);

  RentalTrackingRecord copyWith({
    InvoicePreference? invoicePreference,
    List<RentalBillingPeriod>? billingPeriods,
    List<RentalItemRate>? itemRates,
    List<RentalDocument>? documents,
  }) {
    return RentalTrackingRecord(
      id: id,
      customer: customer,
      address: address,
      originalOutboundDate: originalOutboundDate,
      items: items,
      movements: movements,
      invoicePreference: invoicePreference ?? this.invoicePreference,
      billingPeriods: billingPeriods ?? this.billingPeriods,
      itemRates: itemRates ?? this.itemRates,
      documents: documents ?? this.documents,
      note: note,
    );
  }

  RentalItemRate? latestRateFor(String productId, {DateTime? at}) {
    final date = at ?? DateTime.now();
    final matches = itemRates
        .where((r) =>
            r.productId == productId &&
            !r.effectiveFrom.isAfter(date))
        .toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return matches.isEmpty ? null : matches.first;
  }

  RentalTrackingRecord addReturn({
    required String movementId,
    required String productId,
    required double quantity,
    required DateTime date,
    RentalReturnCondition condition = RentalReturnCondition.usable,
    String? note,
  }) {
    if (quantity <= 0) return this;

    final updatedItems = items.map((item) {
      if (item.product.id != productId) return item;
      final nextReturned = item.returnedQuantity + quantity;
      final capped = nextReturned > item.initialQuantity
          ? item.initialQuantity
          : nextReturned;
      return item.copyWith(returnedQuantity: capped);
    }).toList();

    final movement = RentalMovement(
      id: movementId,
      rentalRecordId: id,
      productId: productId,
      type: RentalMovementType.inboundReturn,
      quantity: quantity,
      date: date,
      returnCondition: condition,
      note: note,
    );

    return RentalTrackingRecord(
      id: id,
      customer: customer,
      address: address,
      originalOutboundDate: originalOutboundDate,
      items: updatedItems,
      movements: [...movements, movement],
      invoicePreference: invoicePreference,
      billingPeriods: billingPeriods,
      itemRates: itemRates,
      documents: documents,
      note: this.note,
    );
  }
}

enum InvoicePreference { invoiceRequired, noInvoice }

extension InvoicePreferenceLabel on InvoicePreference {
  String get label => switch (this) {
        InvoicePreference.invoiceRequired => 'Faturalı',
        InvoicePreference.noInvoice => 'Faturasız',
      };
}

enum InvoiceStatus { notRequired, pending, issued }

extension InvoiceStatusLabel on InvoiceStatus {
  String get label => switch (this) {
        InvoiceStatus.notRequired => 'Fatura gerekmiyor',
        InvoiceStatus.pending => 'Fatura bekliyor',
        InvoiceStatus.issued => 'Fatura kesildi',
      };
}

enum PaymentStatus { pending, partial, paid }

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.pending => 'Ödeme bekliyor',
        PaymentStatus.partial => 'Kısmi ödendi',
        PaymentStatus.paid => 'Ödendi',
      };
}

class RentalBillingPeriod {
  final String id;
  final String rentalRecordId;
  final DateTime renewalDate;
  final InvoicePreference invoicePreference;
  final InvoiceStatus invoiceStatus;
  final DateTime? invoiceDate;
  final String? invoiceNo;
  final PaymentStatus paymentStatus;
  final double? billedAmount;
  final double? paidAmount;

  const RentalBillingPeriod({
    required this.id,
    required this.rentalRecordId,
    required this.renewalDate,
    required this.invoicePreference,
    required this.invoiceStatus,
    this.invoiceDate,
    this.invoiceNo,
    this.paymentStatus = PaymentStatus.pending,
    this.billedAmount,
    this.paidAmount,
  });

  bool get invoiceReminderNeeded =>
      invoicePreference == InvoicePreference.invoiceRequired &&
      invoiceStatus == InvoiceStatus.pending;

  RentalBillingPeriod copyWith({
    InvoicePreference? invoicePreference,
    InvoiceStatus? invoiceStatus,
    DateTime? invoiceDate,
    String? invoiceNo,
    PaymentStatus? paymentStatus,
    double? billedAmount,
    double? paidAmount,
  }) {
    return RentalBillingPeriod(
      id: id,
      rentalRecordId: rentalRecordId,
      renewalDate: renewalDate,
      invoicePreference: invoicePreference ?? this.invoicePreference,
      invoiceStatus: invoiceStatus ?? this.invoiceStatus,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      billedAmount: billedAmount ?? this.billedAmount,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

enum RentalRateType { perUnitMonthly, fixedMonthly }

extension RentalRateTypeLabel on RentalRateType {
  String get label => switch (this) {
        RentalRateType.perUnitMonthly => 'Birim başı / aylık',
        RentalRateType.fixedMonthly => 'Sabit / aylık',
      };
}

class RentalItemRate {
  final String id;
  final String rentalRecordId;
  final String productId;
  final DateTime effectiveFrom;
  final double amount;
  final RentalRateType rateType;
  final String currencyCode;
  final String? note;

  const RentalItemRate({
    required this.id,
    required this.rentalRecordId,
    required this.productId,
    required this.effectiveFrom,
    required this.amount,
    this.rateType = RentalRateType.perUnitMonthly,
    this.currencyCode = 'TRY',
    this.note,
  });
}

enum RentalDocumentType {
  contract,
  outboundDelivery,
  inboundDelivery,
  invoice,
  other,
}

extension RentalDocumentTypeLabel on RentalDocumentType {
  String get label => switch (this) {
        RentalDocumentType.contract => 'Kira Sözleşmesi',
        RentalDocumentType.outboundDelivery => 'Giden Sevkiyat Belgesi',
        RentalDocumentType.inboundDelivery => 'Gelen Sevkiyat Belgesi',
        RentalDocumentType.invoice => 'Fatura',
        RentalDocumentType.other => 'Diğer Belge',
      };
}

class RentalDocument {
  final String id;
  final String rentalRecordId;
  final String? rentalMovementId;
  final RentalDocumentType type;
  final String fileName;
  final String storagePath;
  final String? mimeType;
  final DateTime uploadedAt;
  final String? uploadedByUserId;
  final String? note;

  const RentalDocument({
    required this.id,
    required this.rentalRecordId,
    this.rentalMovementId,
    required this.type,
    required this.fileName,
    required this.storagePath,
    this.mimeType,
    required this.uploadedAt,
    this.uploadedByUserId,
    this.note,
  });
}

enum AppUserRole { admin, staff, viewer }

extension AppUserRoleLabel on AppUserRole {
  String get label => switch (this) {
        AppUserRole.admin => 'Yönetici',
        AppUserRole.staff => 'Personel',
        AppUserRole.viewer => 'Sadece Görüntüleme',
      };
}

enum RentalReturnCondition { usable, repair, scrap }

extension RentalReturnConditionLabel on RentalReturnCondition {
  String get label => switch (this) {
        RentalReturnCondition.usable => 'Kullanılabilir',
        RentalReturnCondition.repair => 'Tamirlik',
        RentalReturnCondition.scrap => 'Hurda',
      };
}

