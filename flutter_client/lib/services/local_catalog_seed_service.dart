import '../data/seed_products.dart';
import 'local_domain_cache.dart';

class LocalCatalogSeedService {
  LocalCatalogSeedService({LocalDomainCache? cache})
      : cache = cache ?? LocalDomainCache();

  final LocalDomainCache cache;

  Future<void> ensureSeeded() async {
    final existing = await cache.products();
    if (existing.length >= products.length) return;

    for (final p in products) {
      await cache.upsertProduct(
        id: p.id,
        name: p.name,
        category: p.category.name,
        unit: p.unit.name,
        tradeMode: p.tradeMode.name,
        stockConfidence: p.stockConfidence.name,
      );
    }
  }
}
