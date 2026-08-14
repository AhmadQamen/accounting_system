enum DocumentStatus { draft, posted, voided }

enum PartyType { customer, supplier, both }

enum CashDirection { input, output }

enum InventoryMovementType {
  openingBalance,
  purchase,
  sale,
  saleReturn,
  purchaseReturn,
  waste,
  adjustment,
  transferIn,
  transferOut,
  reversal,
}

extension PartyTypeDb on PartyType {
  String get dbValue => name;
}

extension CashDirectionDb on CashDirection {
  String get dbValue => this == CashDirection.input ? 'in' : 'out';
}
