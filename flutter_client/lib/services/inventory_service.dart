import '../models/models.dart';

enum StockMovementType {
  opening,
  purchase,
  shipment,
  returnFromCustomer,
  sale,
  scrap,
  lost,
  countAdjustment,
  repairIn,
  repairOut,
}

class StockMovement {
  final String productId;
  final StockMovementType type;
  final double quantity;
  final DateTime date;

  const StockMovement({
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
  });
}

class InventorySnapshot {
  final double warehouse;
  final double atCustomers;
  final double inRepair;
  final double scrapOrLost;

  const InventorySnapshot({
    required this.warehouse,
    required this.atCustomers,
    required this.inRepair,
    required this.scrapOrLost,
  });
}

class InventoryService {
  InventorySnapshot calculate(
    Product product,
    Iterable<StockMovement> allMovements,
  ) {
    var warehouse = 0.0;
    var atCustomers = 0.0;
    var inRepair = 0.0;
    var scrapOrLost = 0.0;

    for (final m in allMovements.where((e) => e.productId == product.id)) {
      switch (m.type) {
        case StockMovementType.opening:
        case StockMovementType.purchase:
        case StockMovementType.returnFromCustomer:
        case StockMovementType.countAdjustment:
          warehouse += m.quantity;
        case StockMovementType.shipment:
        case StockMovementType.sale:
          warehouse -= m.quantity;
          if (m.type == StockMovementType.shipment) {
            atCustomers += m.quantity;
          }
        case StockMovementType.scrap:
        case StockMovementType.lost:
          warehouse -= m.quantity;
          scrapOrLost += m.quantity;
        case StockMovementType.repairIn:
          warehouse -= m.quantity;
          inRepair += m.quantity;
        case StockMovementType.repairOut:
          inRepair -= m.quantity;
          warehouse += m.quantity;
      }

      if (m.type == StockMovementType.returnFromCustomer) {
        atCustomers -= m.quantity;
      }
    }

    return InventorySnapshot(
      warehouse: warehouse,
      atCustomers: atCustomers,
      inRepair: inRepair,
      scrapOrLost: scrapOrLost,
    );
  }
}
