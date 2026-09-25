import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:sqflite/sqflite.dart';

class UnsupportedDomainEventException implements Exception {
  const UnsupportedDomainEventException(this.eventType);
  final String eventType;
  @override
  String toString() => 'Event type $eventType is not supported.';
}

class DomainEventApplyException implements Exception {
  const DomainEventApplyException(this.eventId, this.eventType, this.message);
  final String eventId;
  final String eventType;
  final String message;
  @override
  String toString() => 'تعذر تطبيق $eventType ($eventId): $message';
}

abstract interface class DomainEventProjector {
  Future<void> apply(
    Transaction transaction, {
    required String entityId,
    required DomainEvent event,
  });
}

class SqliteDomainEventProjector implements DomainEventProjector {
  const SqliteDomainEventProjector();

  @override
  Future<void> apply(
    Transaction db, {
    required String entityId,
    required DomainEvent event,
  }) async {
    try {
      final t = event.eventType;
      late Future<void> projection;
      if (_masterEvents.contains(t)) {
        projection = _master(db, entityId, event);
      } else if (t == 'CashOpeningBalanceSet') {
        projection = _cashOpening(db, entityId, event);
      } else if (t == 'CashAdjustmentPosted') {
        projection = _cashAdjustment(db, entityId, event);
      } else if (t == 'CashTransferred') {
        projection = _cashTransfer(db, entityId, event);
      } else if (t == 'InventoryOpeningPosted') {
        projection = _inventoryOpening(db, entityId, event);
      } else if (t == 'InventoryAdjusted') {
        projection = _inventoryAdjustment(db, entityId, event);
      } else if (t == 'InventoryTransferred') {
        projection = _inventoryTransfer(db, entityId, event);
      } else if (t == 'SalePosted') {
        projection = _document(db, entityId, event, 'sale');
      } else if (t == 'PurchasePosted') {
        projection = _document(db, entityId, event, 'purchase');
      } else if (t == 'SaleReturnPosted') {
        projection = _document(db, entityId, event, 'sale_return');
      } else if (t == 'PurchaseReturnPosted') {
        projection = _document(db, entityId, event, 'purchase_return');
      } else if (t == 'WastePosted') {
        projection = _waste(db, entityId, event);
      } else if (t == 'ExpensePosted') {
        projection = _expense(db, entityId, event);
      } else if (t == 'PartyPaymentPosted') {
        projection = _partyPayment(db, entityId, event);
      } else if (t == 'SaleVoided') {
        projection = _void(db, entityId, event, 'sale');
      } else if (t == 'PurchaseVoided') {
        projection = _void(db, entityId, event, 'purchase');
      } else if (t == 'ExpenseVoided') {
        projection = _void(db, entityId, event, 'expense');
      } else if (t == 'PartyPaymentVoided') {
        projection = _void(db, entityId, event, 'party_payment');
      } else {
        throw UnsupportedDomainEventException(t);
      }
      await projection;
    } on UnsupportedDomainEventException {
      rethrow;
    } on DomainEventApplyException {
      rethrow;
    } catch (error) {
      throw DomainEventApplyException(event.eventId, event.eventType, '$error');
    }
  }

  static const _masterEvents = {
    'PartyCreated',
    'PartyUpdated',
    'PartyDeleted',
    'CategoryCreated',
    'CategoryUpdated',
    'CategoryDeleted',
    'ProductCreated',
    'ProductUpdated',
    'ProductDeleted',
    'ProductUnitCreated',
    'ProductUnitUpdated',
    'ProductUnitDeleted',
    'BarcodeCreated',
    'BarcodeDeleted',
    'WarehouseCreated',
    'WarehouseUpdated',
    'CashboxCreated',
  };

  Future<void> _master(Transaction db, String entity, DomainEvent e) async {
    final t = e.eventType;
    if (t.endsWith('Deleted')) {
      final table =
          t.startsWith('Party')
              ? 'parties'
              : t.startsWith('Category')
              ? 'categories'
              : t.startsWith('ProductUnit')
              ? 'product_units'
              : t.startsWith('Product')
              ? 'products'
              : 'barcodes';
      final n = await db.update(
        table,
        {
          'deleted_at': _s(e, 'deletedAt'),
          'updated_at': _s(e, 'deletedAt'),
          'version': e.aggregateVersion,
        },
        where: 'id=? AND entity_id=?',
        whereArgs: [e.aggregateId, entity],
      );
      if (n != 1) throw StateError('Missing $table/${e.aggregateId}');
      return;
    }
    late String table;
    late Map<String, Object?> values;
    if (t.startsWith('Party')) {
      table = 'parties';
      values = {
        'name': _s(e, 'name'),
        'phone': e.payload['phone'],
        'type': _s(e, 'type').toLowerCase(),
        'updated_at': _s(e, 'updatedAt'),
        'deleted_at': null,
      };
    } else if (t.startsWith('Category')) {
      table = 'categories';
      values = {
        'name': _s(e, 'name'),
        'updated_at': _s(e, 'updatedAt'),
        'deleted_at': null,
      };
    } else if (t.startsWith('ProductUnit')) {
      table = 'product_units';
      values = {
        'product_id': _s(e, 'productId'),
        'name': _s(e, 'name'),
        'factor': _n(e, 'factor'),
        'is_primary': e.payload['primary'] == true ? 1 : 0,
        'sale_price_minor': 0,
        'updated_at': _s(e, 'updatedAt'),
        'deleted_at': null,
      };
    } else if (t.startsWith('Product')) {
      table = 'products';
      values = {
        'category_id': e.payload['categoryId'],
        'name': _s(e, 'name'),
        'min_quantity': _n(e, 'minQuantity'),
        'updated_at': _s(e, 'updatedAt'),
        'deleted_at': null,
      };
    } else if (t.startsWith('Barcode')) {
      table = 'barcodes';
      values = {
        'product_unit_id': _s(e, 'productUnitId'),
        'code': _s(e, 'code'),
        'updated_at': _s(e, 'createdAt'),
        'deleted_at': null,
      };
    } else if (t.startsWith('Warehouse')) {
      table = 'warehouses';
      values = {
        'name': _s(e, 'name'),
        'updated_at': _s(e, 'updatedAt'),
        'deleted_at': null,
      };
    } else {
      table = 'cashboxes';
      values = {
        'name': _s(e, 'name'),
        'updated_at': _s(e, 'createdAt'),
        'deleted_at': null,
      };
    }
    await _upsert(db, table, e.aggregateId, {
      'entity_id': entity,
      ...values,
      'created_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
  }

  Future<void> _cashOpening(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final box = _s(e, 'cashboxId');
    await _need(db, 'cashboxes', box, entity);
    final amount = _i(e, 'amountMinor');
    if (amount == 0) throw StateError('amountMinor=0');
    final year = await _year(db, entity, null, e.occurredAt);
    await _cashMove(
      db,
      entity: entity,
      id: _s(e, 'transactionId'),
      year: year,
      box: box,
      direction: amount > 0 ? 'in' : 'out',
      kind: 'opening_balance',
      amount: amount.abs(),
      refType: 'cash_opening_balance',
      refId: e.aggregateId,
      note: e.payload['note']?.toString(),
      at: e.occurredAt,
    );
    await _cashBalance(db, box);
  }

  Future<void> _cashAdjustment(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final box = _s(e, 'cashboxId');
    await _need(db, 'cashboxes', box, entity);
    final year = await _year(db, entity, null, e.occurredAt);
    final direction = _dir(e, 'direction');
    final amount = _positive(e, 'amountMinor');
    await _upsert(db, 'cash_adjustments', e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      'adjustment_number': _s(e, 'adjustmentNumber'),
      'cashbox_id': box,
      'direction': direction,
      'amount_minor': amount,
      'status': 'posted',
      'note': _s(e, 'reason'),
      'occurred_at': e.occurredAt,
      'posted_at': e.occurredAt,
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    await _cashMove(
      db,
      entity: entity,
      id: _s(e, 'transactionId'),
      year: year,
      box: box,
      direction: direction,
      kind: 'adjustment',
      amount: amount,
      refType: 'cash_adjustment',
      refId: e.aggregateId,
      note: _s(e, 'reason'),
      at: e.occurredAt,
    );
    await _cashBalance(db, box);
  }

  Future<void> _cashTransfer(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final from = _s(e, 'fromCashboxId'), to = _s(e, 'toCashboxId');
    await _need(db, 'cashboxes', from, entity);
    await _need(db, 'cashboxes', to, entity);
    final year = await _year(db, entity, null, e.occurredAt),
        amount = _positive(e, 'amountMinor');
    await _upsert(db, 'cash_transfers', e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      'transfer_number': _s(e, 'transferNumber'),
      'from_cashbox_id': from,
      'to_cashbox_id': to,
      'amount_minor': amount,
      'status': 'posted',
      'note': e.payload['note'],
      'occurred_at': e.occurredAt,
      'posted_at': e.occurredAt,
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    await _cashMove(
      db,
      entity: entity,
      id: _s(e, 'outTransactionId'),
      year: year,
      box: from,
      direction: 'out',
      kind: 'transfer',
      amount: amount,
      refType: 'cash_transfer',
      refId: e.aggregateId,
      at: e.occurredAt,
    );
    await _cashMove(
      db,
      entity: entity,
      id: _s(e, 'inTransactionId'),
      year: year,
      box: to,
      direction: 'in',
      kind: 'transfer',
      amount: amount,
      refType: 'cash_transfer',
      refId: e.aggregateId,
      at: e.occurredAt,
    );
    await _cashBalance(db, from);
    await _cashBalance(db, to);
  }

  Future<void> _inventoryOpening(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        wh = _s(e, 'warehouseId');
    await _need(db, 'warehouses', wh, entity);
    for (final x in _items(e)) {
      final inv = _ms(x, 'inventoryItemId');
      await _inventoryItem(
        db,
        entity,
        inv,
        _ms(x, 'productId'),
        wh,
        e.occurredAt,
      );
      await _inventoryMove(
        db,
        entity: entity,
        id: _ms(x, 'movementId'),
        year: year,
        inventory: inv,
        type: 'opening_balance',
        quantity: _mn(x, 'baseQuantity'),
        value: _mi(x, 'valueMinor'),
        refType: 'opening_balance',
        refId: e.aggregateId,
        at: e.occurredAt,
      );
      await _inventoryBalance(db, inv);
    }
  }

  Future<void> _inventoryAdjustment(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        wh = _s(e, 'warehouseId');
    await _need(db, 'warehouses', wh, entity);
    await _upsert(db, 'inventory_adjustments', e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      'warehouse_id': wh,
      'adjustment_number': _s(e, 'adjustmentNumber'),
      'status': 'posted',
      'note': e.payload['note'],
      'occurred_at': e.occurredAt,
      'posted_at': e.occurredAt,
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    for (final x in _items(e)) {
      final inv = _ms(x, 'inventoryItemId'), movement = _ms(x, 'movementId');
      await _need(db, 'inventory_items', inv, entity);
      await _upsert(db, 'inventory_adjustment_items', movement, {
        'entity_id': entity,
        'inventory_adjustment_id': e.aggregateId,
        'inventory_item_id': inv,
        'product_unit_id': _ms(x, 'productUnitId'),
        'quantity_before': _mn(x, 'quantityBefore'),
        'counted_quantity': _mn(x, 'countedQuantity'),
        'quantity_delta': _mn(x, 'quantityDelta'),
        'unit_factor_at_adjustment': _mn(x, 'unitFactor'),
        'value_delta_minor': _mi(x, 'valueDeltaMinor'),
        'created_at': e.occurredAt,
      });
      await _inventoryMove(
        db,
        entity: entity,
        id: movement,
        year: year,
        inventory: inv,
        type: 'adjustment',
        quantity: _mn(x, 'quantityDelta'),
        value: _mi(x, 'valueDeltaMinor'),
        refType: 'inventory_adjustment',
        refId: e.aggregateId,
        itemId: movement,
        at: e.occurredAt,
      );
      await _inventoryBalance(db, inv);
    }
  }

  Future<void> _inventoryTransfer(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        from = _s(e, 'fromWarehouseId'),
        to = _s(e, 'toWarehouseId');
    await _need(db, 'warehouses', from, entity);
    await _need(db, 'warehouses', to, entity);
    await _upsert(db, 'inventory_transfers', e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      'transfer_number': _s(e, 'transferNumber'),
      'from_warehouse_id': from,
      'to_warehouse_id': to,
      'status': 'posted',
      'note': e.payload['note'],
      'occurred_at': e.occurredAt,
      'posted_at': e.occurredAt,
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    for (final x in _items(e)) {
      final product = _ms(x, 'productId'),
          src = await _inventoryFor(db, entity, product, from, e.occurredAt),
          dst = await _inventoryFor(db, entity, product, to, e.occurredAt),
          itemId = '${e.aggregateId}:${_ms(x, 'outMovementId')}';
      final q = _mn(x, 'baseQuantity'), v = _mi(x, 'inventoryValueMinor');
      await _upsert(db, 'inventory_transfer_items', itemId, {
        'entity_id': entity,
        'inventory_transfer_id': e.aggregateId,
        'product_id': product,
        'product_unit_id': _ms(x, 'productUnitId'),
        'quantity': _mn(x, 'quantity'),
        'unit_factor_at_transfer': _mn(x, 'unitFactor'),
        'base_quantity': q,
        'inventory_value_minor': v,
        'created_at': e.occurredAt,
      });
      await _inventoryMove(
        db,
        entity: entity,
        id: _ms(x, 'outMovementId'),
        year: year,
        inventory: src,
        type: 'transfer_out',
        quantity: -q,
        value: -v,
        refType: 'inventory_transfer',
        refId: e.aggregateId,
        itemId: itemId,
        at: e.occurredAt,
      );
      await _inventoryMove(
        db,
        entity: entity,
        id: _ms(x, 'inMovementId'),
        year: year,
        inventory: dst,
        type: 'transfer_in',
        quantity: q,
        value: v,
        refType: 'inventory_transfer',
        refId: e.aggregateId,
        itemId: itemId,
        at: e.occurredAt,
      );
      await _inventoryBalance(db, src);
      await _inventoryBalance(db, dst);
    }
  }

  Future<void> _document(
    Transaction db,
    String entity,
    DomainEvent e,
    String type,
  ) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        wh = _s(e, 'warehouseId');
    await _need(db, 'warehouses', wh, entity);
    final isReturn = type.endsWith('_return');
    final table =
        {
          'sale': 'sales',
          'purchase': 'purchase_invoices',
          'sale_return': 'sale_return_invoices',
          'purchase_return': 'purchase_return_invoices',
        }[type]!;
    await _upsert(db, table, e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      isReturn ? 'return_number' : 'invoice_number': _s(e, 'documentNumber'),
      if (type == 'purchase')
        'supplier_invoice_number': e.payload['supplierInvoiceNumber'],
      if (type == 'sale_return') 'sale_id': e.payload['originalSaleId'],
      if (type == 'purchase_return')
        'purchase_invoice_id': e.payload['originalPurchaseId'],
      'party_id': e.payload['partyId'],
      'status': 'posted',
      'subtotal_minor': _i(e, 'subtotalMinor'),
      'discount_minor': _i(e, 'discountMinor'),
      'final_minor': _i(e, 'finalMinor'),
      isReturn ? 'refunded_minor' : 'paid_minor': _i(
        e,
        isReturn ? 'refundedMinor' : 'paidMinor',
      ),
      'cashbox_id': e.payload['cashboxId'],
      'note': e.payload['note'],
      'occurred_at': e.occurredAt,
      'posted_at': _s(e, 'postedAt'),
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    final itemTable =
            {
              'sale': 'sale_items',
              'purchase': 'purchase_items',
              'sale_return': 'sale_return_items',
              'purchase_return': 'purchase_return_items',
            }[type]!,
        fk =
            {
              'sale': 'sale_id',
              'purchase': 'purchase_invoice_id',
              'sale_return': 'sale_return_invoice_id',
              'purchase_return': 'purchase_return_invoice_id',
            }[type]!;
    for (final x in _items(e)) {
      final item = _ms(x, 'itemId'), inv = _ms(x, 'inventoryItemId');
      await _inventoryItem(
        db,
        entity,
        inv,
        _ms(x, 'productId'),
        wh,
        e.occurredAt,
      );
      final unitFactor =
          type == 'sale'
              ? 'unit_factor_at_sale'
              : type == 'purchase'
              ? 'unit_factor_at_purchase'
              : 'unit_factor_at_return';
      final vals = <String, Object?>{
        'entity_id': entity,
        fk: e.aggregateId,
        if (type == 'sale_return') 'sale_item_id': x['originalSaleItemId'],
        if (type == 'purchase_return')
          'purchase_item_id': x['originalPurchaseItemId'],
        'inventory_item_id': inv,
        'product_unit_id': _ms(x, 'productUnitId'),
        'quantity': _mn(x, 'quantity'),
        unitFactor: _mn(x, 'unitFactor'),
        'base_quantity': _mn(x, 'baseQuantity'),
        type.startsWith('sale') ? 'unit_price_minor' : 'unit_cost_minor': _mi(
          x,
          'unitAmountMinor',
        ),
        if (!isReturn) 'line_discount_minor': _mi(x, 'lineDiscountMinor'),
        'line_total_minor': _mi(x, 'lineTotalMinor'),
        if (type != 'purchase_return')
          'cost_amount_minor': _mi(x, 'costAmountMinor'),
        if (type == 'sale') 'net_amount_minor': _mi(x, 'lineTotalMinor'),
        'created_at': e.occurredAt,
        if (!isReturn) 'updated_at': e.occurredAt,
        if (!isReturn) 'version': 1,
      };
      await _upsert(db, itemTable, item, vals);
      final q = _mn(x, 'baseQuantity'), cost = _mi(x, 'costAmountMinor');
      final mt = type,
          qd = (type == 'sale' || type == 'purchase_return') ? -q : q,
          vd = (type == 'sale' || type == 'purchase_return') ? -cost : cost;
      await _inventoryMove(
        db,
        entity: entity,
        id: _ms(x, 'inventoryMovementId'),
        year: year,
        inventory: inv,
        type: mt,
        quantity: qd,
        value: vd,
        refType: type,
        refId: e.aggregateId,
        itemId: item,
        at: e.occurredAt,
      );
      await _inventoryBalance(db, inv);
    }
    await _documentLedgers(db, entity, e, type, year);
  }

  Future<void> _documentLedgers(
    Transaction db,
    String entity,
    DomainEvent e,
    String type,
    String year,
  ) async {
    final party = e.payload['partyId']?.toString(),
        isReturn = type.endsWith('_return'),
        paid = _i(e, isReturn ? 'refundedMinor' : 'paidMinor'),
        total = _i(e, 'finalMinor');
    if (party != null) {
      await _need(db, 'parties', party, entity);
      final delta =
          {
            'sale': total,
            'purchase': -total,
            'sale_return': -total,
            'purchase_return': total,
          }[type]!;
      await _partyMove(
        db,
        entity: entity,
        id: e.payload['partyLedgerEntryId']?.toString() ?? '${e.eventId}:party',
        year: year,
        party: party,
        type: type,
        delta: delta,
        refType: type,
        refId: e.aggregateId,
        at: e.occurredAt,
      );
    }
    if (paid > 0) {
      final box = e.payload['cashboxId']?.toString();
      if (box == null) throw StateError('cashboxId missing');
      await _need(db, 'cashboxes', box, entity);
      final dir = (type == 'sale' || type == 'purchase_return') ? 'in' : 'out',
          tx =
              e.payload['cashTransactionId']?.toString() ?? '${e.eventId}:cash';
      final kind =
          {
            'sale': 'sale_payment',
            'purchase': 'purchase_payment',
            'sale_return': 'sale_refund',
            'purchase_return': 'purchase_refund',
          }[type]!;
      await _cashMove(
        db,
        entity: entity,
        id: tx,
        year: year,
        box: box,
        direction: dir,
        kind: kind,
        amount: paid,
        refType: type,
        refId: e.aggregateId,
        party: party,
        at: e.occurredAt,
      );
      await _cashBalance(db, box);
      if (party != null)
        await _partyMove(
          db,
          entity: entity,
          id: '${e.eventId}:party:payment',
          year: year,
          party: party,
          transaction: tx,
          type: '${type}_payment',
          delta: dir == 'in' ? -paid : paid,
          refType: type,
          refId: e.aggregateId,
          at: e.occurredAt,
        );
    }
    if (party != null) await _partyBalance(db, party);
  }

  Future<void> _waste(Transaction db, String entity, DomainEvent e) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        wh = _s(e, 'warehouseId');
    await _need(db, 'warehouses', wh, entity);
    final xs = _items(e),
        total = xs.fold<int>(0, (v, x) => v + _mi(x, 'costAmountMinor'));
    await _upsert(db, 'waste_invoices', e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      'waste_number': _s(e, 'documentNumber'),
      'status': 'posted',
      'total_cost_minor': total,
      'note': _s(e, 'reason'),
      'occurred_at': e.occurredAt,
      'posted_at': _s(e, 'postedAt'),
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    for (final x in xs) {
      final id = _ms(x, 'itemId'), inv = _ms(x, 'inventoryItemId');
      await _inventoryItem(
        db,
        entity,
        inv,
        _ms(x, 'productId'),
        wh,
        e.occurredAt,
      );
      await _upsert(db, 'waste_items', id, {
        'entity_id': entity,
        'waste_invoice_id': e.aggregateId,
        'inventory_item_id': inv,
        'product_unit_id': _ms(x, 'productUnitId'),
        'quantity': _mn(x, 'quantity'),
        'unit_factor_at_waste': _mn(x, 'unitFactor'),
        'base_quantity': _mn(x, 'baseQuantity'),
        'cost_amount_minor': _mi(x, 'costAmountMinor'),
        'created_at': e.occurredAt,
      });
      await _inventoryMove(
        db,
        entity: entity,
        id: _ms(x, 'inventoryMovementId'),
        year: year,
        inventory: inv,
        type: 'waste',
        quantity: -_mn(x, 'baseQuantity'),
        value: -_mi(x, 'costAmountMinor'),
        refType: 'waste',
        refId: e.aggregateId,
        itemId: id,
        at: e.occurredAt,
      );
      await _inventoryBalance(db, inv);
    }
  }

  Future<void> _expense(Transaction db, String entity, DomainEvent e) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        box = _s(e, 'cashboxId'),
        amount = _positive(e, 'amountMinor');
    await _need(db, 'cashboxes', box, entity);
    await _upsert(db, 'expenses', e.aggregateId, {
      'entity_id': entity,
      'financial_year_id': year,
      'expense_number': _s(e, 'expenseNumber'),
      'cashbox_id': box,
      'amount_minor': amount,
      'status': 'posted',
      'note': e.payload['note'],
      'occurred_at': e.occurredAt,
      'posted_at': _s(e, 'postedAt'),
      'created_at': e.occurredAt,
      'updated_at': e.occurredAt,
      'version': e.aggregateVersion,
    });
    await _cashMove(
      db,
      entity: entity,
      id: _s(e, 'cashTransactionId'),
      year: year,
      box: box,
      direction: 'out',
      kind: 'expense',
      amount: amount,
      refType: 'expense',
      refId: e.aggregateId,
      note: e.payload['note']?.toString(),
      at: e.occurredAt,
    );
    await _cashBalance(db, box);
  }

  Future<void> _partyPayment(
    Transaction db,
    String entity,
    DomainEvent e,
  ) async {
    final year = await _year(
          db,
          entity,
          _s(e, 'financialYearId'),
          e.occurredAt,
        ),
        party = _s(e, 'partyId'),
        box = _s(e, 'cashboxId'),
        receive = _s(e, 'direction') == 'RECEIVE',
        amount = _positive(e, 'amountMinor'),
        tx = _s(e, 'cashTransactionId'),
        at = _s(e, 'postedAt');
    await _need(db, 'parties', party, entity);
    await _need(db, 'cashboxes', box, entity);
    await _cashMove(
      db,
      entity: entity,
      id: tx,
      year: year,
      box: box,
      direction: receive ? 'in' : 'out',
      kind: 'party_payment',
      amount: amount,
      refType: 'party_payment',
      refId: e.aggregateId,
      party: party,
      note: e.payload['note']?.toString(),
      at: at,
    );
    await _partyMove(
      db,
      entity: entity,
      id: _s(e, 'partyLedgerEntryId'),
      year: year,
      party: party,
      transaction: tx,
      type: 'party_payment',
      delta: receive ? -amount : amount,
      refType: 'party_payment',
      refId: e.aggregateId,
      note: e.payload['note']?.toString(),
      at: at,
    );
    await _cashBalance(db, box);
    await _partyBalance(db, party);
  }

  Future<void> _void(
    Transaction db,
    String entity,
    DomainEvent e,
    String type,
  ) async {
    for (final r in _maps(e.payload['reversals'], 'reversals')) {
      final ledger = _ms(r, 'ledgerType'),
          id = _ms(r, 'reversalId'),
          original = _ms(r, 'reversalOfId'),
          at = _s(e, 'voidedAt');
      if (ledger == 'CASH') {
        final o = await _byId(db, 'transactions', original);
        await _cashMove(
          db,
          entity: entity,
          id: id,
          year: o['financial_year_id'] as String,
          box: o['cashbox_id'] as String,
          direction: o['direction'] == 'in' ? 'out' : 'in',
          kind: 'reversal',
          amount: (o['amount_minor'] as num).toInt(),
          refType: '${type}_void',
          refId: e.aggregateId,
          party: o['party_id'] as String?,
          reversal: original,
          note: _s(e, 'reason'),
          at: at,
        );
        await _cashBalance(db, o['cashbox_id'] as String);
      } else if (ledger == 'INVENTORY') {
        final o = await _byId(db, 'inventory_movements', original);
        await _inventoryMove(
          db,
          entity: entity,
          id: id,
          year: o['financial_year_id'] as String,
          inventory: o['inventory_item_id'] as String,
          type: 'reversal',
          quantity: -(o['quantity_delta'] as num).toDouble(),
          value: -(o['value_delta_minor'] as num).toInt(),
          refType: '${type}_void',
          refId: e.aggregateId,
          itemId: o['reference_item_id'] as String?,
          reversal: original,
          at: at,
        );
        await _inventoryBalance(db, o['inventory_item_id'] as String);
      } else if (ledger == 'PARTY') {
        final o = await _byId(db, 'party_ledger_entries', original);
        await _partyMove(
          db,
          entity: entity,
          id: id,
          year: o['financial_year_id'] as String,
          party: o['party_id'] as String,
          type: 'reversal',
          delta: -(o['balance_delta_minor'] as num).toInt(),
          refType: '${type}_void',
          refId: e.aggregateId,
          reversal: original,
          note: _s(e, 'reason'),
          at: at,
        );
        await _partyBalance(db, o['party_id'] as String);
      } else {
        throw StateError('Unknown ledgerType $ledger');
      }
    }
    if (type == 'party_payment') return;
    final table =
        {
          'sale': 'sales',
          'purchase': 'purchase_invoices',
          'expense': 'expenses',
        }[type]!;
    final n = await db.update(
      table,
      {
        'status': 'void',
        'voided_at': _s(e, 'voidedAt'),
        'updated_at': _s(e, 'voidedAt'),
        'version': e.aggregateVersion,
      },
      where: 'id=? AND entity_id=?',
      whereArgs: [e.aggregateId, entity],
    );
    if (n != 1) throw StateError('Missing original $type/${e.aggregateId}');
  }

  Future<void> _upsert(
    Transaction db,
    String table,
    String id,
    Map<String, Object?> values,
  ) async {
    await db.insert(table, {
      'id': id,
      ...values,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (await db.update(table, values, where: 'id=?', whereArgs: [id]) != 1)
      throw StateError('Cannot upsert $table/$id');
  }

  Future<void> _need(
    Transaction db,
    String table,
    String id,
    String entity,
  ) async {
    if ((await db.query(
      table,
      columns: ['id'],
      where: 'id=? AND entity_id=?',
      whereArgs: [id, entity],
      limit: 1,
    )).isEmpty)
      throw StateError('Missing dependency $table/$id');
  }

  Future<Map<String, Object?>> _byId(
    Transaction db,
    String table,
    String id,
  ) async {
    final r = await db.query(table, where: 'id=?', whereArgs: [id], limit: 1);
    if (r.isEmpty) throw StateError('Missing reversal source $table/$id');
    return r.single;
  }

  Future<String> _year(
    Transaction db,
    String entity,
    String? requested,
    String at,
  ) async {
    if (requested != null) {
      final r = await db.query(
        'financial_years',
        columns: ['id'],
        where: 'id=? AND entity_id=?',
        whereArgs: [requested, entity],
        limit: 1,
      );
      if (r.isEmpty)
        await db.insert('financial_years', {
          'id': requested,
          'entity_id': entity,
          'name': 'Synced financial year',
          'starts_on': '1900-01-01T00:00:00Z',
          'ends_on': '2999-12-31T23:59:59Z',
          'is_open': 1,
          'created_at': at,
          'updated_at': at,
          'version': 1,
        });
      return requested;
    }
    final r = await db.query(
      'organization_contexts',
      columns: ['financial_year_id'],
      where: 'entity_id=?',
      whereArgs: [entity],
      limit: 1,
    );
    final id = r.isEmpty ? null : r.single['financial_year_id']?.toString();
    if (id == null || id.isEmpty)
      throw StateError('financialYearId unavailable');
    return id;
  }

  Future<void> _inventoryItem(
    Transaction db,
    String entity,
    String id,
    String product,
    String warehouse,
    String at,
  ) async {
    await _need(db, 'products', product, entity);
    await _need(db, 'warehouses', warehouse, entity);
    final r = await db.query(
      'inventory_items',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (r.isEmpty) {
      await db.insert('inventory_items', {
        'id': id,
        'entity_id': entity,
        'product_id': product,
        'warehouse_id': warehouse,
        'current_quantity': 0.0,
        'inventory_value_minor': 0,
        'updated_at': at,
        'version': 1,
      });
    } else if (r.single['product_id'] != product ||
        r.single['warehouse_id'] != warehouse) {
      throw StateError('inventoryItemId $id has conflicting ownership');
    }
  }

  Future<String> _inventoryFor(
    Transaction db,
    String entity,
    String product,
    String warehouse,
    String at,
  ) async {
    final r = await db.query(
      'inventory_items',
      columns: ['id'],
      where: 'entity_id=? AND product_id=? AND warehouse_id=?',
      whereArgs: [entity, product, warehouse],
      limit: 1,
    );
    if (r.isNotEmpty) return r.single['id'] as String;
    final id = '$entity:$product:$warehouse';
    await _inventoryItem(db, entity, id, product, warehouse, at);
    return id;
  }

  Future<void> _inventoryMove(
    Transaction db, {
    required String entity,
    required String id,
    required String year,
    required String inventory,
    required String type,
    required double quantity,
    required int value,
    required String refType,
    required String refId,
    String? itemId,
    String? reversal,
    required String at,
  }) async {
    await db.insert('inventory_movements', {
      'id': id,
      'entity_id': entity,
      'financial_year_id': year,
      'inventory_item_id': inventory,
      'movement_type': type,
      'quantity_delta': quantity,
      'value_delta_minor': value,
      'reference_type': refType,
      'reference_id': refId,
      'reference_item_id': itemId,
      'reversal_of_id': reversal,
      'occurred_at': at,
      'created_at': at,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _cashMove(
    Transaction db, {
    required String entity,
    required String id,
    required String year,
    required String box,
    required String direction,
    required String kind,
    required int amount,
    required String refType,
    required String refId,
    String? party,
    String? reversal,
    String? note,
    required String at,
  }) async {
    await db.insert('transactions', {
      'id': id,
      'entity_id': entity,
      'financial_year_id': year,
      'cashbox_id': box,
      'party_id': party,
      'direction': direction,
      'kind': kind,
      'amount_minor': amount,
      'reference_type': refType,
      'reference_id': refId,
      'reversal_of_id': reversal,
      'note': note,
      'occurred_at': at,
      'created_at': at,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _partyMove(
    Transaction db, {
    required String entity,
    required String id,
    required String year,
    required String party,
    String? transaction,
    required String type,
    required int delta,
    required String refType,
    required String refId,
    String? reversal,
    String? note,
    required String at,
  }) async {
    await db.insert('party_ledger_entries', {
      'id': id,
      'entity_id': entity,
      'financial_year_id': year,
      'party_id': party,
      'transaction_id': transaction,
      'entry_type': type,
      'balance_delta_minor': delta,
      'reference_type': refType,
      'reference_id': refId,
      'reversal_of_id': reversal,
      'note': note,
      'occurred_at': at,
      'created_at': at,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _inventoryBalance(Transaction db, String id) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity_delta),0) q,COALESCE(SUM(value_delta_minor),0) v FROM inventory_movements WHERE inventory_item_id=?',
      [id],
    );
    await db.update(
      'inventory_items',
      {
        'current_quantity': (r.single['q'] as num).toDouble(),
        'inventory_value_minor': (r.single['v'] as num).toInt(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> _cashBalance(Transaction db, String id) async {
    final r = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE direction WHEN 'in' THEN amount_minor ELSE -amount_minor END),0) v FROM transactions WHERE cashbox_id=?",
      [id],
    );
    await db.update(
      'cashboxes',
      {
        'current_balance_minor': (r.single['v'] as num).toInt(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> _partyBalance(Transaction db, String id) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(balance_delta_minor),0) v FROM party_ledger_entries WHERE party_id=?',
      [id],
    );
    await db.update(
      'parties',
      {
        'current_balance_minor': (r.single['v'] as num).toInt(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  String _s(DomainEvent e, String k) {
    final v = e.payload[k]?.toString();
    if (v == null || v.isEmpty)
      throw FormatException('${e.eventType} missing $k');
    return v;
  }

  int _i(DomainEvent e, String k) {
    final v = e.payload[k];
    if (v is! int) throw FormatException('${e.eventType}.$k must be integer');
    return v;
  }

  int _positive(DomainEvent e, String k) {
    final v = _i(e, k);
    if (v <= 0) throw FormatException('$k must be positive');
    return v;
  }

  double _n(DomainEvent e, String k) {
    final v = e.payload[k];
    if (v is! num) throw FormatException('${e.eventType}.$k must be numeric');
    return v.toDouble();
  }

  String _dir(DomainEvent e, String k) {
    final v = _s(e, k).toLowerCase();
    if (v != 'in' && v != 'out') throw FormatException('$k must be IN/OUT');
    return v;
  }

  List<Map<String, dynamic>> _items(DomainEvent e) =>
      _maps(e.payload['items'], 'items');
  List<Map<String, dynamic>> _maps(Object? value, String key) {
    if (value is! List) throw FormatException('$key must be array');
    return value.map((x) {
      if (x is! Map) throw FormatException('$key item must be object');
      return Map<String, dynamic>.from(x);
    }).toList();
  }

  String _ms(Map<String, dynamic> m, String k) {
    final v = m[k]?.toString();
    if (v == null || v.isEmpty) throw FormatException('item missing $k');
    return v;
  }

  int _mi(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is! int) throw FormatException('item.$k must be integer');
    return v;
  }

  double _mn(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is! num) throw FormatException('item.$k must be numeric');
    return v.toDouble();
  }
}
