import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const inventorySchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS inventory_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  warehouse_id TEXT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  current_quantity REAL NOT NULL DEFAULT 0,
  inventory_value_minor INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, product_id, warehouse_id)
)
''',
  '''
CREATE TABLE IF NOT EXISTS inventory_movements (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  movement_type TEXT NOT NULL CHECK(movement_type IN ('opening_balance','purchase','sale','sale_return','purchase_return','waste','adjustment','transfer_in','transfer_out','reversal')),
  quantity_delta REAL NOT NULL,
  value_delta_minor INTEGER NOT NULL,
  reference_type TEXT NOT NULL,
  reference_id TEXT NOT NULL,
  reference_item_id TEXT,
  reversal_of_id TEXT REFERENCES inventory_movements(id) ON DELETE RESTRICT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS inventory_adjustments (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  warehouse_id TEXT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  adjustment_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  note TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, adjustment_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS inventory_adjustment_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  inventory_adjustment_id TEXT NOT NULL REFERENCES inventory_adjustments(id) ON DELETE CASCADE,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity_before REAL NOT NULL,
  counted_quantity REAL NOT NULL,
  quantity_delta REAL NOT NULL,
  unit_factor_at_adjustment REAL NOT NULL CHECK(unit_factor_at_adjustment > 0),
  value_delta_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS inventory_transfers (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  transfer_number TEXT NOT NULL,
  from_warehouse_id TEXT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  to_warehouse_id TEXT NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  note TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  CHECK(from_warehouse_id <> to_warehouse_id),
  UNIQUE(entity_id, transfer_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS inventory_transfer_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  inventory_transfer_id TEXT NOT NULL REFERENCES inventory_transfers(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK(quantity > 0),
  unit_factor_at_transfer REAL NOT NULL CHECK(unit_factor_at_transfer > 0),
  base_quantity REAL NOT NULL CHECK(base_quantity > 0),
  inventory_value_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
''',
  'CREATE INDEX IF NOT EXISTS idx_inventory_item_product_warehouse ON inventory_items(entity_id, product_id, warehouse_id)',
  'CREATE INDEX IF NOT EXISTS idx_inventory_movements_item ON inventory_movements(inventory_item_id, occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_inventory_movements_reference ON inventory_movements(reference_type, reference_id)',
  'CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_status ON inventory_adjustments(entity_id, status)',
  'CREATE INDEX IF NOT EXISTS idx_inventory_transfers_status ON inventory_transfers(entity_id, status)',
];

Future<void> createInventorySchema(DatabaseExecutor db) =>
    executeStatements(db, inventorySchemaStatements);
