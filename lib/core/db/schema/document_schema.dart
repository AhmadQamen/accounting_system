import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const documentSchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS sales (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  invoice_number TEXT NOT NULL,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  party_id TEXT REFERENCES parties(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  subtotal_minor INTEGER NOT NULL DEFAULT 0,
  discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(discount_minor >= 0),
  final_minor INTEGER NOT NULL DEFAULT 0,
  paid_minor INTEGER NOT NULL DEFAULT 0 CHECK(paid_minor >= 0),
  cashbox_id TEXT,
  note TEXT,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, invoice_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS sale_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  sale_id TEXT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK(quantity > 0),
  unit_factor_at_sale REAL NOT NULL CHECK(unit_factor_at_sale > 0),
  base_quantity REAL NOT NULL CHECK(base_quantity > 0),
  unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
  line_discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(line_discount_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK(line_total_minor >= 0),
  net_amount_minor INTEGER NOT NULL DEFAULT 0,
  cost_amount_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS purchase_invoices (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  invoice_number TEXT NOT NULL,
  supplier_invoice_number TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  party_id TEXT REFERENCES parties(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  subtotal_minor INTEGER NOT NULL DEFAULT 0,
  discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(discount_minor >= 0),
  final_minor INTEGER NOT NULL DEFAULT 0,
  paid_minor INTEGER NOT NULL DEFAULT 0 CHECK(paid_minor >= 0),
  cashbox_id TEXT,
  note TEXT,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, invoice_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS purchase_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  purchase_invoice_id TEXT NOT NULL REFERENCES purchase_invoices(id) ON DELETE CASCADE,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK(quantity > 0),
  unit_factor_at_purchase REAL NOT NULL CHECK(unit_factor_at_purchase > 0),
  base_quantity REAL NOT NULL CHECK(base_quantity > 0),
  unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor >= 0),
  line_discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(line_discount_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK(line_total_minor >= 0),
  cost_amount_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS sale_return_invoices (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  return_number TEXT NOT NULL,
  sale_id TEXT REFERENCES sales(id) ON DELETE RESTRICT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  party_id TEXT REFERENCES parties(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  subtotal_minor INTEGER NOT NULL DEFAULT 0,
  discount_minor INTEGER NOT NULL DEFAULT 0,
  final_minor INTEGER NOT NULL DEFAULT 0,
  refunded_minor INTEGER NOT NULL DEFAULT 0,
  cashbox_id TEXT,
  note TEXT,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, return_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS sale_return_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  sale_return_invoice_id TEXT NOT NULL REFERENCES sale_return_invoices(id) ON DELETE CASCADE,
  sale_item_id TEXT REFERENCES sale_items(id) ON DELETE RESTRICT,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK(quantity > 0),
  unit_factor_at_return REAL NOT NULL CHECK(unit_factor_at_return > 0),
  base_quantity REAL NOT NULL CHECK(base_quantity > 0),
  unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK(line_total_minor >= 0),
  cost_amount_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS purchase_return_invoices (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  return_number TEXT NOT NULL,
  purchase_invoice_id TEXT REFERENCES purchase_invoices(id) ON DELETE RESTRICT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  party_id TEXT REFERENCES parties(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  subtotal_minor INTEGER NOT NULL DEFAULT 0,
  discount_minor INTEGER NOT NULL DEFAULT 0,
  final_minor INTEGER NOT NULL DEFAULT 0,
  refunded_minor INTEGER NOT NULL DEFAULT 0,
  cashbox_id TEXT,
  note TEXT,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, return_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS purchase_return_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  purchase_return_invoice_id TEXT NOT NULL REFERENCES purchase_return_invoices(id) ON DELETE CASCADE,
  purchase_item_id TEXT REFERENCES purchase_items(id) ON DELETE RESTRICT,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK(quantity > 0),
  unit_factor_at_return REAL NOT NULL CHECK(unit_factor_at_return > 0),
  base_quantity REAL NOT NULL CHECK(base_quantity > 0),
  unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK(line_total_minor >= 0),
  created_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS waste_invoices (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  waste_number TEXT NOT NULL,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  total_cost_minor INTEGER NOT NULL DEFAULT 0,
  note TEXT,
  occurred_at TEXT NOT NULL,
  posted_at TEXT,
  voided_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, waste_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS waste_items (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  waste_invoice_id TEXT NOT NULL REFERENCES waste_invoices(id) ON DELETE CASCADE,
  inventory_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  quantity REAL NOT NULL CHECK(quantity > 0),
  unit_factor_at_waste REAL NOT NULL CHECK(unit_factor_at_waste > 0),
  base_quantity REAL NOT NULL CHECK(base_quantity > 0),
  cost_amount_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
''',
  'CREATE INDEX IF NOT EXISTS idx_sales_entity_date ON sales(entity_id, occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(entity_id, status)',
  'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
  'CREATE INDEX IF NOT EXISTS idx_purchase_entity_date ON purchase_invoices(entity_id, occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice ON purchase_items(purchase_invoice_id)',
  'CREATE INDEX IF NOT EXISTS idx_sale_returns_sale ON sale_return_invoices(sale_id)',
  'CREATE INDEX IF NOT EXISTS idx_purchase_returns_purchase ON purchase_return_invoices(purchase_invoice_id)',
  'CREATE INDEX IF NOT EXISTS idx_waste_status ON waste_invoices(entity_id, status)',
];

Future<void> createDocumentSchema(DatabaseExecutor db) =>
    executeStatements(db, documentSchemaStatements);
