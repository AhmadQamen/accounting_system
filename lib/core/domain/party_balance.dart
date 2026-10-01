/// The accounting meaning of a party balance is determined only by its sign.
/// It must never be inferred from whether the party is a customer or supplier.
enum PartyBalanceStatus { receivable, payable, settled }

extension PartyBalanceMinorX on int {
  PartyBalanceStatus get partyBalanceStatus =>
      this > 0
          ? PartyBalanceStatus.receivable
          : this < 0
          ? PartyBalanceStatus.payable
          : PartyBalanceStatus.settled;

  String get partyBalanceLabel => switch (partyBalanceStatus) {
    PartyBalanceStatus.receivable => 'مدين لنا',
    PartyBalanceStatus.payable => 'مستحق له',
    PartyBalanceStatus.settled => 'متوازن',
  };

  /// Amount intended for display. The status above communicates the direction.
  int get partyDisplayAmountMinor => abs();
}

String partyLedgerEntryLabel(String entryType) => switch (entryType) {
  'sale' => 'فاتورة بيع',
  'sale_payment' => 'قبض فاتورة بيع',
  'sale_return' => 'مرتجع بيع',
  'sale_refund' => 'رد مبلغ بيع',
  'purchase' => 'فاتورة شراء',
  'purchase_payment' => 'دفع فاتورة شراء',
  'purchase_return' => 'مرتجع شراء',
  'purchase_refund' => 'قبض مرتجع شراء',
  'party_payment' => 'دفعة طرف',
  'reversal' => 'حركة عكسية',
  _ => 'حركة طرف',
};
