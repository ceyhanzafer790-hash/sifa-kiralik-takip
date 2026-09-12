import '../models/models.dart';

const products = <Product>[
  // Plywood & OSB (7)
  Product(id: 'p01', name: 'RİGA FORM PLYWOOD', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),
  Product(id: 'p02', name: 'WODEX PLYWOOD', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),
  Product(id: 'p03', name: 'PERM BİRCH PLYWOOD', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),
  Product(id: 'p04', name: '18 MM OSB', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),
  Product(id: 'p05', name: '15 MM OSB', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),
  Product(id: 'p06', name: '9 MM OSB', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),
  Product(id: 'p07', name: '11 MM OSB', category: ProductCategory.plywoodOsb, unit: UnitType.sheet),

  // Kereste / H20 (7)
  Product(id: 'p08', name: 'Doka H20', category: ProductCategory.timberH20, unit: UnitType.piece),
  Product(id: 'p09', name: 'Extraform H20', category: ProductCategory.timberH20, unit: UnitType.piece),
  Product(id: 'p10', name: 'Form-On H20 Ahşap Kiriş', category: ProductCategory.timberH20, unit: UnitType.piece),
  Product(id: 'p11', name: 'H20 Kancası', category: ProductCategory.timberH20, unit: UnitType.piece),
  Product(id: 'p12', name: 'H20 Birleştirme Aparatı', category: ProductCategory.timberH20, unit: UnitType.piece),
  Product(id: 'p13', name: 'H20 Ahşap Kiriş – RUS', category: ProductCategory.timberH20, unit: UnitType.piece),
  Product(id: 'p14', name: 'H20 Ahşap Kiriş – M Wood', category: ProductCategory.timberH20, unit: UnitType.piece),

  // İskele & Bağlantı (10)
  Product(id: 'p15', name: 'Ara Bağlantı, Nibel', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p16', name: 'Hareketli Kelepçe 48×48 mm', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p17', name: 'ALÜMİNYUM MOBİL İSKELE', category: ProductCategory.scaffoldConnection, unit: UnitType.set, tradeMode: TradeMode.rental),
  Product(id: 'p18', name: 'İskele Kelepçesi Tij 12 mm', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p19', name: 'Asansör Kelepçesi', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p20', name: 'Sabit Kelepçe (Alman Tipi) 48 mm', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p21', name: 'VKZ – SRZ ARA BAĞLANTI 100 CM', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p22', name: 'Masa İskele Çerçeve 150×180 – 3 mm Boyalı', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p23', name: 'Masa İskele Çapraz', category: ProductCategory.scaffoldConnection, unit: UnitType.piece),
  Product(id: 'p24', name: 'H Tipi Güvenlikli İskele', category: ProductCategory.scaffoldConnection, unit: UnitType.set, tradeMode: TradeMode.rental),

  // Direk & Ayar (7)
  Product(id: 'p25', name: '4 YOLLU BAŞLIK 120 CM BOYALI 8 mm', category: ProductCategory.propAdjustment, unit: UnitType.piece),
  Product(id: 'p26', name: 'TELESKOPİK DİKME DİREK', category: ProductCategory.propAdjustment, unit: UnitType.piece, tradeMode: TradeMode.rental),
  Product(id: 'p27', name: 'Ayar Mili Ø 38 – 4 mm', category: ProductCategory.propAdjustment, unit: UnitType.piece),
  Product(id: 'p28', name: '120 cm 48’lik Alt Ayar Mili', category: ProductCategory.propAdjustment, unit: UnitType.piece),
  Product(id: 'p29', name: 'Ayar Mili Somunu', category: ProductCategory.propAdjustment, unit: UnitType.piece),
  Product(id: 'p30', name: 'Teleskopik Direk Mekanizma Somun ve G Kanca', category: ProductCategory.propAdjustment, unit: UnitType.set),
  Product(id: 'p31', name: 'Ayar Mili Ø 48 – 5 mm', category: ProductCategory.propAdjustment, unit: UnitType.piece),

  // Kalıp / Tayrot / Çiroz (9)
  Product(id: 'p32', name: 'Kalıp Yağı', category: ProductCategory.formworkTie, unit: UnitType.liter, tradeMode: TradeMode.sale),
  Product(id: 'p33', name: 'TAYROT MİLİ (TEİROT MİLİ)', category: ProductCategory.formworkTie, unit: UnitType.meter),
  Product(id: 'p34', name: 'KBS ÇİROZ 4 mm', category: ProductCategory.formworkTie, unit: UnitType.piece),
  Product(id: 'p35', name: 'Galvaniz Kalıp Kilidi – Çiroz 4 mm', category: ProductCategory.formworkTie, unit: UnitType.piece),
  Product(id: 'p36', name: 'Tie-rot Aynası (Tayrot Aynası)', category: ProductCategory.formworkTie, unit: UnitType.piece),
  Product(id: 'p37', name: 'Çakmalı Dübel 12 mm', category: ProductCategory.formworkTie, unit: UnitType.piece, tradeMode: TradeMode.sale),
  Product(id: 'p38', name: '90’lık Tierot Somunu (90’lık Tayrot Somunu)', category: ProductCategory.formworkTie, unit: UnitType.piece),
  Product(id: 'p39', name: '70’lik Tie-rot Somunu (Tayrot Somunu)', category: ProductCategory.formworkTie, unit: UnitType.piece),
  Product(id: 'p40', name: 'KBS Marka Kollu Çiroz Sıkma Makinesi', category: ProductCategory.formworkTie, unit: UnitType.piece),

  // Asansör & Vinç (3)
  Product(id: 'p41', name: 'Karadeniz İnşaat Vinci Trifaze Sessiz Şanzımanlı', category: ProductCategory.elevatorCrane, unit: UnitType.piece, tradeMode: TradeMode.rental),
  Product(id: 'p42', name: 'Asansör Kum Kazanı', category: ProductCategory.elevatorCrane, unit: UnitType.piece),
  Product(id: 'p43', name: 'Asansör Tuğla Sepeti', category: ProductCategory.elevatorCrane, unit: UnitType.piece),

  // Şantiye Malzemeleri (5)
  Product(id: 'p44', name: 'Topraklama Şeridi Galvaniz 30×3,5 mm', category: ProductCategory.siteMaterials, unit: UnitType.meter, tradeMode: TradeMode.sale),
  Product(id: 'p45', name: 'Çivi – İnşaat Çivisi', category: ProductCategory.siteMaterials, unit: UnitType.kilogram, tradeMode: TradeMode.sale),
  Product(id: 'p46', name: 'Malzeme Sepeti / İstifleme Sepeti', category: ProductCategory.siteMaterials, unit: UnitType.piece),
  Product(id: 'p47', name: 'Bağ Teli', category: ProductCategory.siteMaterials, unit: UnitType.kilogram, tradeMode: TradeMode.sale),
  Product(id: 'p48', name: '60’lık Beton Vibratörü Kendinden Konvektörlü', category: ProductCategory.siteMaterials, unit: UnitType.piece, tradeMode: TradeMode.rental),
];
