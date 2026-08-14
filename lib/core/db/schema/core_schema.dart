import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const coreSchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS entities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  currency_code TEXT NOT NULL DEFAULT 'USD',
  timezone TEXT NOT NULL DEFAULT 'UTC',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  is_admin INTEGER NOT NULL DEFAULT 0 CHECK(is_admin IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  device_key TEXT NOT NULL,
  name TEXT NOT NULL,
  last_sync_at TEXT,
  last_pulled_server_seq INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revoked_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, device_key)
)
''',
  '''
CREATE TABLE IF NOT EXISTS financial_years (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  starts_on TEXT NOT NULL,
  ends_on TEXT NOT NULL,
  is_open INTEGER NOT NULL DEFAULT 1 CHECK(is_open IN (0,1)),
  closed_at TEXT,
  closed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1
)
''',
  '''
CREATE TABLE IF NOT EXISTS app_context (
  singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
  entity_id TEXT REFERENCES entities(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  financial_year_id TEXT REFERENCES financial_years(id) ON DELETE SET NULL,
  default_warehouse_id TEXT,
  default_cashbox_id TEXT,
  updated_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS keyboard_shortcuts (
  action TEXT PRIMARY KEY,
  key_label TEXT NOT NULL,
  ctrl INTEGER NOT NULL DEFAULT 0,
  shift INTEGER NOT NULL DEFAULT 0,
  alt INTEGER NOT NULL DEFAULT 0
)
''',
  'CREATE INDEX IF NOT EXISTS idx_users_entity ON users(entity_id)',
  'CREATE INDEX IF NOT EXISTS idx_devices_entity ON devices(entity_id)',
  'CREATE INDEX IF NOT EXISTS idx_financial_years_entity ON financial_years(entity_id)',
];

Future<void> createCoreSchema(DatabaseExecutor db) =>
    executeStatements(db, coreSchemaStatements);
