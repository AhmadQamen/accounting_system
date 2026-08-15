import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/utils/app_logger.dart';
import 'package:accounting_system/core/services/cash_ledger_service.dart';
import 'package:accounting_system/core/services/inventory_ledger_service.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:accounting_system/core/services/party_ledger_service.dart';
import 'package:accounting_system/features/documents/models/document_models.dart';
import 'package:sqflite/sqflite.dart';

class DocumentRepository {
  DocumentRepository(this._database);
  final AppDatabase _database;
  final _inventory = const InventoryLedgerService();
  final _cash = const CashLedgerService();
  final _party = const PartyLedgerService();
  final _outbox = const OutboxService();

  Future<List<AccountingDocument>> listDocuments(String type) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final table = _tableForType(type);
    final numberCol = switch (type) {
      'sale' => 'invoice_number',
      'purchase' => 'invoice_number',
      'sale_return' => 'return_number',
      'purchase_return' => 'return_number',
      'waste' => 'waste_number',
      _ => 'id',
    };
    if (type == 'waste') {
      final rows = await db.rawQuery('''
SELECT d.*, d.$numberCol AS display_number, NULL AS party_name
FROM $table d
WHERE d.entity_id=? AND d.deleted_at IS NULL
ORDER BY d.occurred_at DESC LIMIT 500
''', [ctx.entityId]);
      return rows.map((row) => AccountingDocument.fromSql(row, type: type)).toList(growable: false);
    }
    final rows = await db.rawQuery('''
SELECT d.*, d.$numberCol AS display_number, p.name AS party_name
FROM $table d
LEFT JOIN parties p ON p.id=d.party_id
WHERE d.entity_id=? AND d.deleted_at IS NULL
ORDER BY d.occurred_at DESC LIMIT 500
''', [ctx.entityId]);
    return rows.map((row) => AccountingDocument.fromSql(row, type: type)).toList(growable: false);
  }

  Future<String> createSaleDraft({
    String? partyId,
    String? cashboxId,
    int discountMinor = 0,
    int paidMinor = 0,
    String? note,
    required List<SaleLineInput> items,
  }) async {
    if (items.isEmpty) throw ArgumentError('Sale needs at least one item');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('SAL', ctx.deviceId, now);
    await _database.transaction((txn) async {
      final subtotal = items.fold<int>(0, (sum, e) => sum + e.lineTotalMinor);
      if (discountMinor < 0 || discountMinor > subtotal) throw ArgumentError('Invalid discount');
      final finalMinor = subtotal - discountMinor;
      if (paidMinor < 0 || paidMinor > finalMinor) throw ArgumentError('Invalid paid amount');
      await txn.insert('sales', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'invoice_number': number, 'created_by': ctx.userId, 'origin_device_id': ctx.deviceId,
        'party_id': partyId, 'status': 'draft', 'subtotal_minor': subtotal,
        'discount_minor': discountMinor, 'final_minor': finalMinor, 'paid_minor': paidMinor,
        'cashbox_id': cashboxId ?? ctx.defaultCashboxId, 'note': note,
        'occurred_at': now.toIso8601String(), 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      for (final item in items) {
        await txn.insert('sale_items', item.toSql(entityId: ctx.entityId, saleId: id, now: now));
      }
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'sale', aggregateId: id, action: 'draft', payload: await _aggregatePayload(txn, type: 'sale', id: id));
    });
    return id;
  }

  Future<void> postSale(String saleId) async {
    AppLogger.info('post_sale', {'id': saleId});
    final ctx = await LocalContextService.instance.current;
    await _database.transaction((txn) async {
      await _ensureYearOpen(txn, ctx.financialYearId);
      final sale = await _single(txn, 'sales', saleId);
      if (sale['status'] != 'draft') throw StateError('Only draft sales can be posted');
      final items = await txn.query('sale_items', where: 'sale_id=? AND deleted_at IS NULL', whereArgs: [saleId], orderBy: 'created_at ASC, id ASC');
      if (items.isEmpty) throw StateError('Sale has no items');
      final now = DateTime.now().toUtc();
      final subtotalMinor = (sale['subtotal_minor'] as num).toInt();
      final finalMinor = (sale['final_minor'] as num).toInt();
      var remainingGross = subtotalMinor;
      var remainingNet = finalMinor;
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final lineGross = (item['line_total_minor'] as num).toInt();
        final netAmount = index == items.length - 1
            ? remainingNet
            : _allocateInt(remainingNet, lineGross, remainingGross);
        remainingGross -= lineGross;
        remainingNet -= netAmount;
        final inventoryItemId = item['inventory_item_id'] as String;
        await _validateUnitInventory(txn, inventoryItemId, item['product_unit_id'] as String);
        final inv = await _single(txn, 'inventory_items', inventoryItemId);
        final baseQty = (item['base_quantity'] as num).toDouble();
        final qty = (inv['current_quantity'] as num).toDouble();
        if (qty + 0.0000001 < baseQty) throw StateError('Insufficient stock');
        final average = await _inventory.currentAverageUnitCostMinor(txn, inventoryItemId);
        final cost = Money.multiplyByQuantity(average, baseQty);
        await txn.update('sale_items', {'net_amount_minor': netAmount, 'cost_amount_minor': cost, 'updated_at': now.toIso8601String()}, where: 'id=?', whereArgs: [item['id']]);
        await _inventory.recordMovement(txn,
            entityId: ctx.entityId, financialYearId: ctx.financialYearId,
            inventoryItemId: inventoryItemId, movementType: 'sale', quantityDelta: -baseQty,
            valueDeltaMinor: -cost, referenceType: 'sale', referenceId: saleId,
            referenceItemId: item['id'] as String, createdBy: ctx.userId,
            originDeviceId: ctx.deviceId, occurredAt: DateTime.parse(sale['occurred_at'] as String));
      }
      final paidMinor = (sale['paid_minor'] as num).toInt();
      final partyId = sale['party_id'] as String?;
      if (partyId == null && paidMinor != finalMinor) throw StateError('A credit sale requires a customer');
      if (partyId != null) {
        await _party.recordPartyEntry(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, partyId: partyId, entryType: 'sale_invoice', balanceDeltaMinor: finalMinor, referenceType: 'sale', referenceId: saleId, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: DateTime.parse(sale['occurred_at'] as String));
      }
      if (paidMinor > 0) {
        final cashboxId = (sale['cashbox_id'] as String?) ?? ctx.defaultCashboxId;
        final transactionId = await _cash.recordCashTransaction(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, cashboxId: cashboxId, direction: 'in', kind: 'sale_payment', amountMinor: paidMinor, referenceType: 'sale', referenceId: saleId, partyId: partyId, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: DateTime.parse(sale['occurred_at'] as String));
        if (partyId != null) {
          await _party.recordPartyEntry(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, partyId: partyId, transactionId: transactionId, entryType: 'sale_payment', balanceDeltaMinor: -paidMinor, referenceType: 'sale', referenceId: saleId, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: DateTime.parse(sale['occurred_at'] as String));
        }
      }
      await txn.update('sales', {'status': 'posted', 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String(), 'version': (sale['version'] as num).toInt()+1}, where: 'id=?', whereArgs: [saleId]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'sale', aggregateId: saleId, action: 'post', payload: await _aggregatePayload(txn, type: 'sale', id: saleId));
    });
  }

  Future<String> createPurchaseDraft({
    required String supplierId,
    String? cashboxId,
    int discountMinor = 0,
    int paidMinor = 0,
    String? note,
    String? supplierInvoiceNumber,
    required List<PurchaseLineInput> items,
  }) async {
    if (items.isEmpty) throw ArgumentError('Purchase needs at least one item');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('PUR', ctx.deviceId, now);
    await _database.transaction((txn) async {
      final subtotal = items.fold<int>(0, (sum, e) => sum + e.lineTotalMinor);
      final finalMinor = subtotal - discountMinor;
      if (finalMinor < 0 || paidMinor < 0 || paidMinor > finalMinor) throw ArgumentError('Invalid totals');
      await txn.insert('purchase_invoices', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'invoice_number': number, 'supplier_invoice_number': supplierInvoiceNumber,
        'created_by': ctx.userId, 'origin_device_id': ctx.deviceId, 'party_id': supplierId,
        'status': 'draft', 'subtotal_minor': subtotal, 'discount_minor': discountMinor,
        'final_minor': finalMinor, 'paid_minor': paidMinor, 'cashbox_id': cashboxId ?? ctx.defaultCashboxId,
        'note': note, 'occurred_at': now.toIso8601String(), 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      for (final item in items) {
        await txn.insert('purchase_items', item.toSql(entityId: ctx.entityId, purchaseId: id, now: now));
      }
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'purchase', aggregateId: id, action: 'draft', payload: await _aggregatePayload(txn, type: 'purchase', id: id));
    });
    return id;
  }

  Future<void> postPurchase(String purchaseId) async {
    AppLogger.info('post_purchase', {'id': purchaseId});
    final ctx = await LocalContextService.instance.current;
    await _database.transaction((txn) async {
      await _ensureYearOpen(txn, ctx.financialYearId);
      final purchase = await _single(txn, 'purchase_invoices', purchaseId);
      if (purchase['status'] != 'draft') throw StateError('Only draft purchases can be posted');
      final supplierId = purchase['party_id'] as String?;
      if (supplierId == null) throw StateError('Purchase requires supplier');
      final items = await txn.query(
        'purchase_items',
        where: 'purchase_invoice_id=? AND deleted_at IS NULL',
        whereArgs: [purchaseId],
        orderBy: 'created_at ASC, id ASC',
      );
      if (items.isEmpty) throw StateError('Purchase has no items');
      final now = DateTime.now().toUtc();
      final subtotalMinor = (purchase['subtotal_minor'] as num).toInt();
      final finalMinor = (purchase['final_minor'] as num).toInt();
      var remainingGross = subtotalMinor;
      var remainingNet = finalMinor;
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final inventoryItemId = item['inventory_item_id'] as String;
        await _validateUnitInventory(txn, inventoryItemId, item['product_unit_id'] as String);
        final baseQty = (item['base_quantity'] as num).toDouble();
        final lineGross = (item['line_total_minor'] as num).toInt();
        final value = index == items.length - 1
            ? remainingNet
            : _allocateInt(remainingNet, lineGross, remainingGross);
        remainingGross -= lineGross;
        remainingNet -= value;
        await txn.update(
          'purchase_items',
          {'cost_amount_minor': value, 'updated_at': now.toIso8601String()},
          where: 'id=?',
          whereArgs: [item['id']],
        );
        await _inventory.recordMovement(
          txn,
          entityId: ctx.entityId,
          financialYearId: ctx.financialYearId,
          inventoryItemId: inventoryItemId,
          movementType: 'purchase',
          quantityDelta: baseQty,
          valueDeltaMinor: value,
          referenceType: 'purchase',
          referenceId: purchaseId,
          referenceItemId: item['id'] as String,
          createdBy: ctx.userId,
          originDeviceId: ctx.deviceId,
          occurredAt: DateTime.parse(purchase['occurred_at'] as String),
        );
      }
      final paidMinor = (purchase['paid_minor'] as num).toInt();
      await _party.recordPartyEntry(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        partyId: supplierId,
        entryType: 'purchase_invoice',
        balanceDeltaMinor: -finalMinor,
        referenceType: 'purchase',
        referenceId: purchaseId,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
        occurredAt: DateTime.parse(purchase['occurred_at'] as String),
      );
      if (paidMinor > 0) {
        final txId = await _cash.recordCashTransaction(
          txn,
          entityId: ctx.entityId,
          financialYearId: ctx.financialYearId,
          cashboxId: (purchase['cashbox_id'] as String?) ?? ctx.defaultCashboxId,
          direction: 'out',
          kind: 'purchase_payment',
          amountMinor: paidMinor,
          referenceType: 'purchase',
          referenceId: purchaseId,
          partyId: supplierId,
          createdBy: ctx.userId,
          originDeviceId: ctx.deviceId,
          occurredAt: DateTime.parse(purchase['occurred_at'] as String),
        );
        await _party.recordPartyEntry(
          txn,
          entityId: ctx.entityId,
          financialYearId: ctx.financialYearId,
          partyId: supplierId,
          transactionId: txId,
          entryType: 'purchase_payment',
          balanceDeltaMinor: paidMinor,
          referenceType: 'purchase',
          referenceId: purchaseId,
          createdBy: ctx.userId,
          originDeviceId: ctx.deviceId,
          occurredAt: DateTime.parse(purchase['occurred_at'] as String),
        );
      }
      await txn.update(
        'purchase_invoices',
        {
          'status': 'posted',
          'posted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'version': (purchase['version'] as num).toInt() + 1,
        },
        where: 'id=?',
        whereArgs: [purchaseId],
      );
      await _outbox.enqueue(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'purchase',
        aggregateId: purchaseId,
        action: 'post',
        payload: await _aggregatePayload(txn, type: 'purchase', id: purchaseId),
      );
    });
  }

  Future<String> postWaste({required List<WasteLineInput> items, String? note}) async {
    if (items.isEmpty) throw ArgumentError('Waste needs items');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('WST', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await _ensureYearOpen(txn, ctx.financialYearId);
      var totalCost = 0;
      await txn.insert('waste_invoices', {'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId, 'waste_number': number, 'created_by': ctx.userId, 'origin_device_id': ctx.deviceId, 'status': 'draft', 'total_cost_minor': 0, 'note': note, 'occurred_at': now.toIso8601String(), 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String()});
      for (final input in items) {
        final inv = await _single(txn, 'inventory_items', input.inventoryItemId);
        final available = (inv['current_quantity'] as num).toDouble();
        if (available < input.baseQuantity) throw StateError('Insufficient stock for waste');
        final average = await _inventory.currentAverageUnitCostMinor(txn, input.inventoryItemId);
        final cost = Money.multiplyByQuantity(average, input.baseQuantity);
        totalCost += cost;
        final itemId = uuid.v4();
        await txn.insert('waste_items', {'id': itemId, 'entity_id': ctx.entityId, 'waste_invoice_id': id, 'inventory_item_id': input.inventoryItemId, 'product_unit_id': input.productUnitId, 'quantity': input.quantity, 'unit_factor_at_waste': input.unitFactor, 'base_quantity': input.baseQuantity, 'cost_amount_minor': cost, 'created_at': now.toIso8601String()});
        await _inventory.recordMovement(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, inventoryItemId: input.inventoryItemId, movementType: 'waste', quantityDelta: -input.baseQuantity, valueDeltaMinor: -cost, referenceType: 'waste', referenceId: id, referenceItemId: itemId, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
      }
      await txn.update('waste_invoices', {'status': 'posted', 'total_cost_minor': totalCost, 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}, where: 'id=?', whereArgs: [id]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'waste', aggregateId: id, action: 'post', payload: await _aggregatePayload(txn, type: 'waste', id: id));
    });
    return id;
  }

  Future<String> postSaleReturn({
    required String saleId,
    required List<ReturnLineInput> items,
    int refundedMinor = 0,
    String? cashboxId,
    String? note,
  }) async {
    if (items.isEmpty) throw ArgumentError('Return needs items');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('SRT', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await _ensureYearOpen(txn, ctx.financialYearId);
      final sale = await _single(txn, 'sales', saleId);
      if (sale['status'] != 'posted') throw StateError('Original sale must be posted');
      final saleSubtotal = (sale['subtotal_minor'] as num).toInt();
      final saleFinal = (sale['final_minor'] as num).toInt();
      var total = 0;
      await txn.insert('sale_return_invoices', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'return_number': number, 'sale_id': saleId, 'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId, 'party_id': sale['party_id'], 'status': 'draft',
        'subtotal_minor': 0, 'discount_minor': 0, 'final_minor': 0,
        'refunded_minor': refundedMinor, 'cashbox_id': cashboxId ?? sale['cashbox_id'],
        'note': note, 'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      for (final input in items) {
        final original = await _single(txn, 'sale_items', input.originalItemId);
        if (original['sale_id'] != saleId) throw StateError('Return item does not belong to sale');
        final previousRows = await txn.rawQuery(
          '''SELECT COALESCE(SUM(i.base_quantity),0) q,
                    COALESCE(SUM(i.line_total_minor),0) amount,
                    COALESCE(SUM(i.cost_amount_minor),0) cost
             FROM sale_return_items i
             JOIN sale_return_invoices r ON r.id=i.sale_return_invoice_id
             WHERE i.sale_item_id=? AND r.status='posted' ''',
          [input.originalItemId],
        );
        final alreadyQty = (previousRows.first['q'] as num).toDouble();
        final alreadyAmount = (previousRows.first['amount'] as num).toInt();
        final alreadyCost = (previousRows.first['cost'] as num).toInt();
        final sold = (original['base_quantity'] as num).toDouble();
        final cumulativeQty = alreadyQty + input.baseQuantity;
        if (cumulativeQty > sold + 0.0000001) throw StateError('Return exceeds sold quantity');
        final originalGross = (original['line_total_minor'] as num).toInt();
        var originalNet = (original['net_amount_minor'] as num?)?.toInt() ?? 0;
        if (originalNet == 0 && originalGross > 0) {
          originalNet = _allocateInt(saleFinal, originalGross, saleSubtotal);
        }
        final cumulativeAmount = _proportionalByQuantity(originalNet, cumulativeQty, sold);
        final lineTotal = cumulativeAmount - alreadyAmount;
        final originalCost = (original['cost_amount_minor'] as num).toInt();
        final cumulativeCost = _proportionalByQuantity(originalCost, cumulativeQty, sold);
        final cost = cumulativeCost - alreadyCost;
        if (lineTotal < 0 || cost < 0) throw StateError('Invalid return allocation');
        total += lineTotal;
        final itemId = uuid.v4();
        await txn.insert('sale_return_items', {
          'id': itemId, 'entity_id': ctx.entityId, 'sale_return_invoice_id': id,
          'sale_item_id': input.originalItemId, 'inventory_item_id': original['inventory_item_id'],
          'product_unit_id': original['product_unit_id'], 'quantity': input.quantity,
          'unit_factor_at_return': input.unitFactor, 'base_quantity': input.baseQuantity,
          'unit_price_minor': original['unit_price_minor'], 'line_total_minor': lineTotal,
          'cost_amount_minor': cost, 'created_at': now.toIso8601String(),
        });
        await _inventory.recordMovement(
          txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
          inventoryItemId: original['inventory_item_id'] as String,
          movementType: 'sale_return', quantityDelta: input.baseQuantity,
          valueDeltaMinor: cost, referenceType: 'sale_return', referenceId: id,
          referenceItemId: itemId, createdBy: ctx.userId, originDeviceId: ctx.deviceId,
          occurredAt: now,
        );
      }
      final partyId = sale['party_id'] as String?;
      if (partyId != null) {
        await _party.recordPartyEntry(
          txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
          partyId: partyId, entryType: 'sale_return', balanceDeltaMinor: -total,
          referenceType: 'sale_return', referenceId: id, createdBy: ctx.userId,
          originDeviceId: ctx.deviceId, occurredAt: now,
        );
      }
      if (refundedMinor > 0) {
        if (refundedMinor > total) throw StateError('Refund exceeds return total');
        final refundTxId = await _cash.recordCashTransaction(
          txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
          cashboxId: cashboxId ?? (sale['cashbox_id'] as String?) ?? ctx.defaultCashboxId,
          direction: 'out', kind: 'sale_refund', amountMinor: refundedMinor,
          referenceType: 'sale_return', referenceId: id, partyId: partyId,
          createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now,
        );
        if (partyId != null) {
          await _party.recordPartyEntry(
            txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
            partyId: partyId, transactionId: refundTxId, entryType: 'sale_refund',
            balanceDeltaMinor: refundedMinor, referenceType: 'sale_return', referenceId: id,
            createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now,
          );
        }
      }
      await txn.update(
        'sale_return_invoices',
        {'subtotal_minor': total, 'final_minor': total, 'status': 'posted',
         'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()},
        where: 'id=?', whereArgs: [id],
      );
      await _outbox.enqueue(
        txn, entityId: ctx.entityId, aggregateType: 'sale_return', aggregateId: id,
        action: 'post', payload: await _aggregatePayload(txn, type: 'sale_return', id: id),
      );
    });
    return id;
  }

  Future<String> postPurchaseReturn({
    required String purchaseId,
    required List<ReturnLineInput> items,
    int receivedMinor = 0,
    String? cashboxId,
    String? note,
  }) async {
    if (items.isEmpty) throw ArgumentError('Return needs items');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('PRT', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await _ensureYearOpen(txn, ctx.financialYearId);
      final purchase = await _single(txn, 'purchase_invoices', purchaseId);
      if (purchase['status'] != 'posted') throw StateError('Original purchase must be posted');
      final purchaseSubtotal = (purchase['subtotal_minor'] as num).toInt();
      final purchaseFinal = (purchase['final_minor'] as num).toInt();
      var total = 0;
      await txn.insert('purchase_return_invoices', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'return_number': number, 'purchase_invoice_id': purchaseId, 'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId, 'party_id': purchase['party_id'], 'status': 'draft',
        'subtotal_minor': 0, 'discount_minor': 0, 'final_minor': 0,
        'refunded_minor': receivedMinor, 'cashbox_id': cashboxId ?? purchase['cashbox_id'],
        'note': note, 'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      for (final input in items) {
        final original = await _single(txn, 'purchase_items', input.originalItemId);
        if (original['purchase_invoice_id'] != purchaseId) throw StateError('Return item does not belong to purchase');
        final previous = await txn.rawQuery(
          '''SELECT COALESCE(SUM(i.base_quantity),0) q,
                    COALESCE(SUM(i.line_total_minor),0) amount
             FROM purchase_return_items i
             JOIN purchase_return_invoices r ON r.id=i.purchase_return_invoice_id
             WHERE i.purchase_item_id=? AND r.status='posted' ''',
          [input.originalItemId],
        );
        final alreadyQty = (previous.first['q'] as num).toDouble();
        final alreadyAmount = (previous.first['amount'] as num).toInt();
        final purchased = (original['base_quantity'] as num).toDouble();
        final cumulativeQty = alreadyQty + input.baseQuantity;
        if (cumulativeQty > purchased + 0.0000001) throw StateError('Return exceeds purchased quantity');
        final inv = await _single(txn, 'inventory_items', original['inventory_item_id'] as String);
        if ((inv['current_quantity'] as num).toDouble() + 0.0000001 < input.baseQuantity) {
          throw StateError('Insufficient stock to return');
        }
        var originalCost = (original['cost_amount_minor'] as num?)?.toInt() ?? 0;
        if (originalCost == 0 && (original['line_total_minor'] as num).toInt() > 0) {
          originalCost = _allocateInt(
            purchaseFinal,
            (original['line_total_minor'] as num).toInt(),
            purchaseSubtotal,
          );
        }
        final cumulativeAmount = _proportionalByQuantity(originalCost, cumulativeQty, purchased);
        final lineTotal = cumulativeAmount - alreadyAmount;
        if (lineTotal < 0) throw StateError('Invalid purchase return allocation');
        total += lineTotal;
        final itemId = uuid.v4();
        await txn.insert('purchase_return_items', {
          'id': itemId, 'entity_id': ctx.entityId, 'purchase_return_invoice_id': id,
          'purchase_item_id': input.originalItemId, 'inventory_item_id': original['inventory_item_id'],
          'product_unit_id': original['product_unit_id'], 'quantity': input.quantity,
          'unit_factor_at_return': input.unitFactor, 'base_quantity': input.baseQuantity,
          'unit_cost_minor': original['unit_cost_minor'], 'line_total_minor': lineTotal,
          'created_at': now.toIso8601String(),
        });
        await _inventory.recordMovement(
          txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
          inventoryItemId: original['inventory_item_id'] as String,
          movementType: 'purchase_return', quantityDelta: -input.baseQuantity,
          valueDeltaMinor: -lineTotal, referenceType: 'purchase_return', referenceId: id,
          referenceItemId: itemId, createdBy: ctx.userId, originDeviceId: ctx.deviceId,
          occurredAt: now,
        );
      }
      final supplierId = purchase['party_id'] as String?;
      if (supplierId != null) {
        await _party.recordPartyEntry(
          txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
          partyId: supplierId, entryType: 'purchase_return', balanceDeltaMinor: total,
          referenceType: 'purchase_return', referenceId: id, createdBy: ctx.userId,
          originDeviceId: ctx.deviceId, occurredAt: now,
        );
      }
      if (receivedMinor > 0) {
        if (receivedMinor > total) throw StateError('Received amount exceeds return total');
        final refundTxId = await _cash.recordCashTransaction(
          txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
          cashboxId: cashboxId ?? (purchase['cashbox_id'] as String?) ?? ctx.defaultCashboxId,
          direction: 'in', kind: 'purchase_refund', amountMinor: receivedMinor,
          referenceType: 'purchase_return', referenceId: id, partyId: supplierId,
          createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now,
        );
        if (supplierId != null) {
          await _party.recordPartyEntry(
            txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId,
            partyId: supplierId, transactionId: refundTxId, entryType: 'purchase_refund',
            balanceDeltaMinor: -receivedMinor, referenceType: 'purchase_return', referenceId: id,
            createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now,
          );
        }
      }
      await txn.update(
        'purchase_return_invoices',
        {'subtotal_minor': total, 'final_minor': total, 'status': 'posted',
         'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()},
        where: 'id=?', whereArgs: [id],
      );
      await _outbox.enqueue(
        txn, entityId: ctx.entityId, aggregateType: 'purchase_return', aggregateId: id,
        action: 'post', payload: await _aggregatePayload(txn, type: 'purchase_return', id: id),
      );
    });
    return id;
  }

  Future<void> voidDocument(String type, String documentId) async {
    AppLogger.info('void_document', {'type': type, 'id': documentId});
    final ctx = await LocalContextService.instance.current;
    final table = _tableForType(type);
    await _database.transaction((txn) async {
      final document = await _single(txn, table, documentId);
      if (document['entity_id'] != ctx.entityId) {
        throw StateError('Document belongs to another entity');
      }
      if (document['status'] != 'posted') {
        throw StateError('Only posted documents can be voided');
      }
      if (type == 'sale') {
        final rows = await txn.rawQuery(
          "SELECT COUNT(*) c FROM sale_return_invoices WHERE sale_id=? AND status='posted'",
          [documentId],
        );
        if ((rows.first['c'] as num).toInt() > 0) {
          throw StateError('Cannot void a sale that has posted returns');
        }
      }
      if (type == 'purchase') {
        final rows = await txn.rawQuery(
          "SELECT COUNT(*) c FROM purchase_return_invoices r JOIN purchase_return_items i ON i.purchase_return_invoice_id=r.id JOIN purchase_items p ON p.id=i.purchase_item_id WHERE p.purchase_invoice_id=? AND r.status='posted'",
          [documentId],
        );
        if ((rows.first['c'] as num).toInt() > 0) {
          throw StateError('Cannot void a purchase that has posted returns');
        }
      }

      final now = DateTime.now().toUtc();
      final movements = await txn.query(
        'inventory_movements',
        where: 'entity_id=? AND reference_type=? AND reference_id=? AND reversal_of_id IS NULL',
        whereArgs: [ctx.entityId, type, documentId],
      );
      for (final movement in movements) {
        await _inventory.recordMovement(
          txn,
          entityId: ctx.entityId,
          financialYearId: movement['financial_year_id'] as String,
          inventoryItemId: movement['inventory_item_id'] as String,
          movementType: 'reversal',
          quantityDelta: -(movement['quantity_delta'] as num).toDouble(),
          valueDeltaMinor: -(movement['value_delta_minor'] as num).toInt(),
          referenceType: '${type}_void',
          referenceId: documentId,
          referenceItemId: movement['reference_item_id'] as String?,
          reversalOfId: movement['id'] as String,
          createdBy: ctx.userId,
          originDeviceId: ctx.deviceId,
          occurredAt: now,
        );
      }

      final cashRows = await txn.query(
        'transactions',
        where: 'entity_id=? AND reference_type=? AND reference_id=? AND reversal_of_id IS NULL',
        whereArgs: [ctx.entityId, type, documentId],
      );
      for (final cash in cashRows) {
        await _cash.recordCashTransaction(
          txn,
          entityId: ctx.entityId,
          financialYearId: cash['financial_year_id'] as String,
          cashboxId: cash['cashbox_id'] as String,
          direction: cash['direction'] == 'in' ? 'out' : 'in',
          kind: 'reversal',
          amountMinor: (cash['amount_minor'] as num).toInt(),
          referenceType: '${type}_void',
          referenceId: documentId,
          partyId: cash['party_id'] as String?,
          reversalOfId: cash['id'] as String,
          createdBy: ctx.userId,
          originDeviceId: ctx.deviceId,
          occurredAt: now,
        );
      }

      final partyRows = await txn.query(
        'party_ledger_entries',
        where: 'entity_id=? AND reference_type=? AND reference_id=? AND reversal_of_id IS NULL',
        whereArgs: [ctx.entityId, type, documentId],
      );
      for (final entry in partyRows) {
        await _party.recordPartyEntry(
          txn,
          entityId: ctx.entityId,
          financialYearId: entry['financial_year_id'] as String,
          partyId: entry['party_id'] as String,
          entryType: 'reversal',
          balanceDeltaMinor: -(entry['balance_delta_minor'] as num).toInt(),
          referenceType: '${type}_void',
          referenceId: documentId,
          reversalOfId: entry['id'] as String,
          createdBy: ctx.userId,
          originDeviceId: ctx.deviceId,
          occurredAt: now,
        );
      }

      await txn.update(
        table,
        {
          'status': 'void',
          'voided_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'version': (document['version'] as num).toInt() + 1,
        },
        where: 'id=? AND entity_id=?',
        whereArgs: [documentId, ctx.entityId],
      );
      await _outbox.enqueue(
        txn,
        entityId: ctx.entityId,
        aggregateType: type,
        aggregateId: documentId,
        action: 'void',
        payload: await _aggregatePayload(txn, type: type, id: documentId, ledgerReferenceType: '${type}_void'),
      );
    });
  }

  Future<DocumentDetails> documentDetails(String type, String id) async {
    final db = await _database.database;
    final table = _tableForType(type);
    final header = await _single(db, table, id);
    final itemTable = switch (type) {
      'sale' => 'sale_items', 'purchase' => 'purchase_items', 'sale_return' => 'sale_return_items', 'purchase_return' => 'purchase_return_items', 'waste' => 'waste_items', _ => throw ArgumentError(type),
    };
    final fk = switch (type) {
      'sale' => 'sale_id', 'purchase' => 'purchase_invoice_id', 'sale_return' => 'sale_return_invoice_id', 'purchase_return' => 'purchase_return_invoice_id', 'waste' => 'waste_invoice_id', _ => throw ArgumentError(type),
    };
    final items = await db.rawQuery('''
SELECT i.*, p.name AS product_name, u.name AS unit_name
FROM $itemTable i
LEFT JOIN inventory_items inv ON inv.id=i.inventory_item_id
LEFT JOIN products p ON p.id=inv.product_id
LEFT JOIN product_units u ON u.id=i.product_unit_id
WHERE i.$fk=?
ORDER BY i.created_at ASC
''', [id]);
    return DocumentDetails(
      header: AccountingDocument.fromSql(header, type: type),
      items: items.map(DocumentLine.fromSql).toList(growable: false),
    );
  }

  Future<Map<String, Object?>> _aggregatePayload(
    DatabaseExecutor db, {
    required String type,
    required String id,
    String? ledgerReferenceType,
  }) async {
    final table = _tableForType(type);
    final itemTable = switch (type) {
      'sale' => 'sale_items',
      'purchase' => 'purchase_items',
      'sale_return' => 'sale_return_items',
      'purchase_return' => 'purchase_return_items',
      'waste' => 'waste_items',
      _ => throw ArgumentError('Unknown document type: $type'),
    };
    final itemFk = switch (type) {
      'sale' => 'sale_id',
      'purchase' => 'purchase_invoice_id',
      'sale_return' => 'sale_return_invoice_id',
      'purchase_return' => 'purchase_return_invoice_id',
      'waste' => 'waste_invoice_id',
      _ => throw ArgumentError('Unknown document type: $type'),
    };
    final header = await _single(db, table, id);
    final items = await db.query(itemTable, where: '$itemFk=?', whereArgs: [id]);
    final referenceType = ledgerReferenceType ?? type;
    final inventoryMovements = await db.query(
      'inventory_movements',
      where: 'reference_type=? AND reference_id=?',
      whereArgs: [referenceType, id],
      orderBy: 'created_at ASC',
    );
    final cashTransactions = await db.query(
      'transactions',
      where: 'reference_type=? AND reference_id=?',
      whereArgs: [referenceType, id],
      orderBy: 'created_at ASC',
    );
    final partyEntries = await db.query(
      'party_ledger_entries',
      where: 'reference_type=? AND reference_id=?',
      whereArgs: [referenceType, id],
      orderBy: 'created_at ASC',
    );
    return <String, Object?>{
      'header': Map<String, Object?>.from(header),
      'items': items.map((row) => Map<String, Object?>.from(row)).toList(),
      'inventory_movements': inventoryMovements.map((row) => Map<String, Object?>.from(row)).toList(),
      'cash_transactions': cashTransactions.map((row) => Map<String, Object?>.from(row)).toList(),
      'party_ledger_entries': partyEntries.map((row) => Map<String, Object?>.from(row)).toList(),
    };
  }

  String _tableForType(String type) => switch (type) {
    'sale' => 'sales', 'purchase' => 'purchase_invoices', 'sale_return' => 'sale_return_invoices', 'purchase_return' => 'purchase_return_invoices', 'waste' => 'waste_invoices', _ => throw ArgumentError('Unknown document type: $type'),
  };

  Future<Map<String, Object?>> _single(DatabaseExecutor db, String table, String id) async {
    final rows = await db.query(table, where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('$table record not found');
    return rows.first;
  }

  Future<void> _ensureYearOpen(DatabaseExecutor db, String yearId) async {
    final row = await _single(db, 'financial_years', yearId);
    if ((row['is_open'] as num).toInt() != 1) throw StateError('Financial year is closed');
  }

  Future<void> _validateUnitInventory(DatabaseExecutor db, String inventoryItemId, String unitId) async {
    final rows = await db.rawQuery('''SELECT i.product_id inventory_product, u.product_id unit_product FROM inventory_items i JOIN product_units u ON u.id=? WHERE i.id=?''', [unitId, inventoryItemId]);
    if (rows.isEmpty || rows.first['inventory_product'] != rows.first['unit_product']) throw StateError('Product unit does not match inventory item');
  }

  int _allocateInt(int amount, int part, int whole) {
    if (amount <= 0 || part <= 0 || whole <= 0) return 0;
    return ((amount * part) + (whole ~/ 2)) ~/ whole;
  }

  int _proportionalByQuantity(int total, double part, double whole) {
    if (total <= 0 || part <= 0 || whole <= 0) return 0;
    const scale = 1000;
    final partScaled = (part * scale).round();
    final wholeScaled = (whole * scale).round();
    if (wholeScaled <= 0) return 0;
    return ((total * partScaled) + (wholeScaled ~/ 2)) ~/ wholeScaled;
  }

  String _number(String prefix, String deviceId, DateTime now) => '$prefix-${deviceId.substring(0, 4).toUpperCase()}-${now.microsecondsSinceEpoch}';
}
