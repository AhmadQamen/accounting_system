import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const cashSchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS cashboxes (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  current_balance_minor INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(entity_id, name)
)
''',
  '''
CREATE TABLE IF NOT EXISTS cash_sessions (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
  opened_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  closed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')),
  opening_amount_minor INTEGER NOT NULL DEFAULT 0,
  expected_amount_minor INTEGER,
  counted_amount_minor INTEGER,
  difference_minor INTEGER,
  opened_at TEXT NOT NULL,
  closed_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
  cash_session_id TEXT REFERENCES cash_sessions(id) ON DELETE SET NULL,
  party_id TEXT REFERENCES parties(id) ON DELETE SET NULL,
  direction TEXT NOT NULL CHECK(direction IN ('in','out')),
  kind TEXT NOT NULL CHECK(kind IN ('opening_balance','sale_payment','purchase_payment','sale_refund','purchase_refund','expense','transfer','adjustment','party_payment','other','reversal')),
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  reference_type TEXT NOT NULL,
  reference_id TEXT NOT NULL,
  reversal_of_id TEXT REFERENCES transactions(id) ON DELETE RESTRICT,
  note TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS party_ledger_entries (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  party_id TEXT NOT NULL REFERENCES parties(id) ON DELETE RESTRICT,
  transaction_id TEXT REFERENCES transactions(id) ON DELETE SET NULL,
  entry_type TEXT NOT NULL,
  balance_delta_minor INTEGER NOT NULL,
  reference_type TEXT NOT NULL,
  reference_id TEXT NOT NULL,
  reversal_of_id TEXT REFERENCES party_ledger_entries(id) ON DELETE RESTRICT,
  note TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  occurred_at TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  expense_number TEXT NOT NULL,
  cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
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
  UNIQUE(entity_id, expense_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS cash_transfers (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  transfer_number TEXT NOT NULL,
  from_cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
  to_cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
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
  CHECK(from_cashbox_id <> to_cashbox_id),
  UNIQUE(entity_id, transfer_number)
)
''',
  '''
CREATE TABLE IF NOT EXISTS cash_adjustments (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
  adjustment_number TEXT NOT NULL,
  cashbox_id TEXT NOT NULL REFERENCES cashboxes(id) ON DELETE RESTRICT,
  direction TEXT NOT NULL CHECK(direction IN ('in','out')),
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','void')),
  note TEXT NOT NULL,
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
  'CREATE INDEX IF NOT EXISTS idx_cashboxes_entity ON cashboxes(entity_id)',
  'CREATE INDEX IF NOT EXISTS idx_transactions_cashbox_date ON transactions(cashbox_id, occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_transactions_reference ON transactions(reference_type, reference_id)',
  'CREATE INDEX IF NOT EXISTS idx_party_ledger_party_date ON party_ledger_entries(party_id, occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_party_ledger_reference ON party_ledger_entries(reference_type, reference_id)',
  'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(entity_id, occurred_at)',
];

Future<void> createCashSchema(DatabaseExecutor db) =>
    executeStatements(db, cashSchemaStatements);
