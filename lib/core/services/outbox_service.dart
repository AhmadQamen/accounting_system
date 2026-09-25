import 'dart:convert';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:sqflite/sqflite.dart';

class OutboxService {
  const OutboxService();

  Future<String> enqueue(
    DatabaseExecutor db, {
    required String entityId,
    required String aggregateType,
    required String aggregateId,
    required String action,
    required Map<String, Object?> payload,
    String? operationId,
  }) async {
    final id = operationId ?? uuid.v4();
    if (action == 'draft') return id;
    await db.insert('legacy_sync_quarantine', {
      'operation_id': id,
      'entity_id': entityId,
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'legacy_action': action,
      'payload_json': jsonEncode(payload),
      'legacy_status': 'isolated',
      'legacy_created_at': DateTime.now().toUtc().toIso8601String(),
      'quarantine_reason': 'LEGACY_ACTION_HAS_NO_VERIFIED_EVENT_MAPPING',
      'quarantined_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return id;
  }

  Future<String> enqueueEvent(
    DatabaseExecutor db, {
    required String entityId,
    required String aggregateType,
    required String aggregateId,
    required String eventType,
    required int aggregateVersion,
    required DateTime occurredAt,
    required Map<String, Object?> payload,
    String? eventId,
  }) async {
    _validateCatalogEvent(aggregateType, eventType, payload);
    final id = eventId ?? uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final versions = await db.query(
      'sync_aggregate_versions',
      columns: ['aggregate_version'],
      where: 'entity_id=? AND aggregate_type=? AND aggregate_id=?',
      whereArgs: [entityId, aggregateType, aggregateId],
      limit: 1,
    );
    final effectiveVersion =
        versions.isEmpty
            ? aggregateVersion
            : (versions.single['aggregate_version'] as num).toInt() + 1;
    await db.insert('sync_outbox', {
      'event_id': id,
      'entity_id': entityId,
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'event_type': eventType,
      'aggregate_version': effectiveVersion,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'payload_json': jsonEncode(payload),
      'created_at': now,
      'status': 'pending',
    });
    await db.insert('sync_aggregate_versions', {
      'entity_id': entityId,
      'aggregate_type': aggregateType,
      'aggregate_id': aggregateId,
      'aggregate_version': effectiveVersion,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  void _validateCatalogEvent(
    String aggregateType,
    String eventType,
    Map<String, Object?> payload,
  ) {
    const allowed = <String, Set<String>>{
      'party': {'PartyCreated', 'PartyUpdated', 'PartyDeleted'},
      'category': {'CategoryCreated', 'CategoryUpdated', 'CategoryDeleted'},
      'product': {'ProductCreated', 'ProductUpdated', 'ProductDeleted'},
      'product_unit': {
        'ProductUnitCreated',
        'ProductUnitUpdated',
        'ProductUnitDeleted',
      },
      'barcode': {'BarcodeCreated', 'BarcodeDeleted'},
      'warehouse': {'WarehouseCreated', 'WarehouseUpdated'},
      'cashbox': {
        'CashboxCreated',
        'CashOpeningBalanceSet',
        'CashAdjustmentPosted',
      },
      'cash_transfer': {'CashTransferred'},
      'inventory_opening': {'InventoryOpeningPosted'},
      'inventory_adjustment': {'InventoryAdjusted'},
      'inventory_transfer': {'InventoryTransferred'},
      'sale': {'SalePosted', 'SaleVoided'},
      'purchase': {'PurchasePosted', 'PurchaseVoided'},
      'sale_return': {'SaleReturnPosted'},
      'purchase_return': {'PurchaseReturnPosted'},
      'waste': {'WastePosted'},
      'expense': {'ExpensePosted', 'ExpenseVoided'},
      'party_payment': {'PartyPaymentPosted', 'PartyPaymentVoided'},
    };
    if (!(allowed[aggregateType]?.contains(eventType) ?? false)) {
      throw ArgumentError(
        'Event $aggregateType/$eventType is not in EVENT_CATALOG_AR.md',
      );
    }
    const requiredKeys = <String, Set<String>>{
      'PartyCreated': {
        'id',
        'name',
        'type',
        'openingBalanceMinor',
        'active',
        'updatedAt',
      },
      'PartyUpdated': {
        'id',
        'name',
        'type',
        'openingBalanceMinor',
        'active',
        'updatedAt',
      },
      'PartyDeleted': {'id', 'deletedAt'},
      'CategoryCreated': {'id', 'name', 'updatedAt'},
      'CategoryUpdated': {'id', 'name', 'updatedAt'},
      'CategoryDeleted': {'id', 'deletedAt'},
      'ProductCreated': {
        'id',
        'categoryId',
        'name',
        'minQuantity',
        'active',
        'updatedAt',
      },
      'ProductUpdated': {
        'id',
        'categoryId',
        'name',
        'minQuantity',
        'active',
        'updatedAt',
      },
      'ProductDeleted': {'id', 'deletedAt'},
      'ProductUnitCreated': {
        'id',
        'productId',
        'name',
        'factor',
        'primary',
        'updatedAt',
      },
      'ProductUnitUpdated': {
        'id',
        'productId',
        'name',
        'factor',
        'primary',
        'updatedAt',
      },
      'ProductUnitDeleted': {'id', 'productId', 'deletedAt'},
      'BarcodeCreated': {'id', 'productUnitId', 'code', 'createdAt'},
      'BarcodeDeleted': {'id', 'code', 'deletedAt'},
      'WarehouseCreated': {'id', 'name', 'active', 'updatedAt'},
      'WarehouseUpdated': {'id', 'name', 'active', 'updatedAt'},
      'CashboxCreated': {'id', 'name', 'createdAt'},
      'CashOpeningBalanceSet': {
        'cashboxId',
        'amountMinor',
        'note',
        'transactionId',
      },
      'CashAdjustmentPosted': {
        'adjustmentId',
        'adjustmentNumber',
        'cashboxId',
        'direction',
        'amountMinor',
        'reason',
        'transactionId',
      },
      'CashTransferred': {
        'transferId',
        'transferNumber',
        'fromCashboxId',
        'toCashboxId',
        'amountMinor',
        'outTransactionId',
        'inTransactionId',
        'note',
      },
      'InventoryOpeningPosted': {
        'openingId',
        'financialYearId',
        'warehouseId',
        'items',
      },
      'InventoryAdjusted': {
        'adjustmentId',
        'adjustmentNumber',
        'financialYearId',
        'warehouseId',
        'note',
        'items',
      },
      'InventoryTransferred': {
        'transferId',
        'transferNumber',
        'financialYearId',
        'fromWarehouseId',
        'toWarehouseId',
        'note',
        'items',
      },
      'SalePosted': {
        'documentId',
        'documentNumber',
        'financialYearId',
        'partyId',
        'warehouseId',
        'cashboxId',
        'subtotalMinor',
        'discountMinor',
        'finalMinor',
        'paidMinor',
        'note',
        'postedAt',
        'items',
      },
      'PurchasePosted': {
        'documentId',
        'documentNumber',
        'financialYearId',
        'partyId',
        'warehouseId',
        'cashboxId',
        'subtotalMinor',
        'discountMinor',
        'finalMinor',
        'paidMinor',
        'note',
        'postedAt',
        'items',
      },
      'SaleReturnPosted': {
        'documentId',
        'documentNumber',
        'financialYearId',
        'partyId',
        'warehouseId',
        'cashboxId',
        'subtotalMinor',
        'discountMinor',
        'finalMinor',
        'refundedMinor',
        'note',
        'postedAt',
        'items',
      },
      'PurchaseReturnPosted': {
        'documentId',
        'documentNumber',
        'financialYearId',
        'partyId',
        'warehouseId',
        'cashboxId',
        'subtotalMinor',
        'discountMinor',
        'finalMinor',
        'refundedMinor',
        'note',
        'postedAt',
        'items',
      },
      'WastePosted': {
        'documentId',
        'documentNumber',
        'financialYearId',
        'warehouseId',
        'reason',
        'postedAt',
        'items',
      },
      'SaleVoided': {'documentId', 'reason', 'voidedAt', 'reversals'},
      'PurchaseVoided': {'documentId', 'reason', 'voidedAt', 'reversals'},
      'ExpensePosted': {
        'expenseId',
        'expenseNumber',
        'financialYearId',
        'cashboxId',
        'amountMinor',
        'note',
        'cashTransactionId',
        'postedAt',
      },
      'ExpenseVoided': {'documentId', 'reason', 'voidedAt', 'reversals'},
      'PartyPaymentPosted': {
        'paymentId',
        'paymentNumber',
        'financialYearId',
        'partyId',
        'cashboxId',
        'direction',
        'amountMinor',
        'cashTransactionId',
        'partyLedgerEntryId',
        'note',
        'postedAt',
      },
      'PartyPaymentVoided': {'documentId', 'reason', 'voidedAt', 'reversals'},
    };
    final missing = requiredKeys[eventType]!.difference(payload.keys.toSet());
    if (missing.isNotEmpty) {
      throw ArgumentError(
        '$eventType payload is missing: ${missing.join(', ')}',
      );
    }
    void checkKeys(Object? value) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          if (key.contains('_')) {
            throw ArgumentError('Event payload key must be camelCase: $key');
          }
          if (key.endsWith('Minor') &&
              entry.value != null &&
              entry.value is! int) {
            throw ArgumentError('Money payload value must be an integer: $key');
          }
          checkKeys(entry.value);
        }
      } else if (value is Iterable) {
        for (final item in value) {
          checkKeys(item);
        }
      }
    }

    checkKeys(payload);
  }
}
