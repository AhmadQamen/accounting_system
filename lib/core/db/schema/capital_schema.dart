import 'package:sqflite/sqflite.dart';

import 'schema_utils.dart';

const capitalSchemaStatements = <String>[
  '''CREATE TABLE IF NOT EXISTS capital_partners (
    id TEXT PRIMARY KEY,
    entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    ownership_bps INTEGER CHECK(ownership_bps IS NULL OR (ownership_bps >= 0 AND ownership_bps <= 10000)),
    gl_account_id TEXT NOT NULL REFERENCES gl_accounts(id) ON DELETE RESTRICT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(entity_id, financial_year_id, name)
  )''',
  '''CREATE TABLE IF NOT EXISTS capital_contributions (
    id TEXT PRIMARY KEY,
    entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
    partner_id TEXT REFERENCES capital_partners(id) ON DELETE RESTRICT,
    -- تسجيل رأس المال لا يعني بالضرورة أن المبلغ دخل صندوقاً بعد.
    -- تخصيصه للصندوق يحفظ لاحقاً في capital_cash_allocations.
    cashbox_id TEXT REFERENCES cashboxes(id) ON DELETE RESTRICT,
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    note TEXT,
    occurred_at TEXT NOT NULL,
    created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL,
    UNIQUE(entity_id, financial_year_id, id)
  )''',
  '''CREATE TABLE IF NOT EXISTS capital_cash_allocations (
    id TEXT PRIMARY KEY,
    entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
    cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    note TEXT,
    occurred_at TEXT NOT NULL,
    created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_capital_partners_entity_year ON capital_partners(entity_id, financial_year_id)',
  'CREATE INDEX IF NOT EXISTS idx_capital_contributions_entity_year ON capital_contributions(entity_id, financial_year_id, occurred_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_capital_allocations_entity_year ON capital_cash_allocations(entity_id, financial_year_id, occurred_at DESC)',
];

Future<void> createCapitalSchema(DatabaseExecutor db) =>
    executeStatements(db, capitalSchemaStatements);
