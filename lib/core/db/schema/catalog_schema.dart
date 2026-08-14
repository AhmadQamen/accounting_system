import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const catalogSchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS parties (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  type TEXT NOT NULL DEFAULT 'customer' CHECK(type IN ('customer','supplier','both')),
  current_balance_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, name)
)
''',
  '''
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  min_quantity REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS product_specifications (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  value TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS product_units (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  factor REAL NOT NULL DEFAULT 1 CHECK(factor > 0),
  is_primary INTEGER NOT NULL DEFAULT 0 CHECK(is_primary IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS barcodes (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  product_unit_id TEXT NOT NULL REFERENCES product_units(id) ON DELETE RESTRICT,
  code TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, code)
)
''',
  '''
CREATE TABLE IF NOT EXISTS warehouses (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, name)
)
''',
  'CREATE INDEX IF NOT EXISTS idx_parties_entity ON parties(entity_id)',
  'CREATE INDEX IF NOT EXISTS idx_parties_type ON parties(entity_id, type)',
  'CREATE INDEX IF NOT EXISTS idx_products_entity ON products(entity_id)',
  'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
  'CREATE INDEX IF NOT EXISTS idx_product_units_product ON product_units(product_id)',
  'CREATE INDEX IF NOT EXISTS idx_barcodes_code ON barcodes(entity_id, code)',
  'CREATE INDEX IF NOT EXISTS idx_warehouses_entity ON warehouses(entity_id)',
  '''
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_primary_unit_per_product
ON product_units(product_id)
WHERE is_primary = 1 AND deleted_at IS NULL
''',
];

Future<void> createCatalogSchema(DatabaseExecutor db) =>
    executeStatements(db, catalogSchemaStatements);
