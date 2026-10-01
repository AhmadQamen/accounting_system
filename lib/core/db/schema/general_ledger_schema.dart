import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const generalLedgerSchemaStatements = <String>[
  '''CREATE TABLE IF NOT EXISTS gl_accounts (
    id TEXT PRIMARY KEY, entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    code TEXT NOT NULL, name TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK(account_type IN ('asset','liability','equity','revenue','expense')),
    parent_id TEXT REFERENCES gl_accounts(id) ON DELETE RESTRICT,
    is_group INTEGER NOT NULL DEFAULT 0 CHECK(is_group IN (0,1)), is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
    UNIQUE(entity_id, code)
  )''',
  '''CREATE TABLE IF NOT EXISTS gl_account_links (
    id TEXT PRIMARY KEY, entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    link_type TEXT NOT NULL CHECK(link_type IN ('cashbox','inventory','customers_control','suppliers_control')),
    source_id TEXT, account_id TEXT NOT NULL REFERENCES gl_accounts(id) ON DELETE RESTRICT,
    created_at TEXT NOT NULL, UNIQUE(entity_id, link_type, source_id)
  )''',
  '''CREATE TABLE IF NOT EXISTS gl_journal_entries (
    id TEXT PRIMARY KEY, entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
    entry_number TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('posted','reversed')),
    source_type TEXT NOT NULL, source_id TEXT NOT NULL, event_id TEXT,
    occurred_at TEXT NOT NULL, note TEXT, reversal_of_id TEXT REFERENCES gl_journal_entries(id) ON DELETE RESTRICT,
    created_at TEXT NOT NULL, UNIQUE(entity_id, financial_year_id, source_type, source_id), UNIQUE(entity_id, event_id)
  )''',
  '''CREATE TABLE IF NOT EXISTS gl_journal_lines (
    id TEXT PRIMARY KEY, entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    journal_entry_id TEXT NOT NULL REFERENCES gl_journal_entries(id) ON DELETE CASCADE,
    account_id TEXT NOT NULL REFERENCES gl_accounts(id) ON DELETE RESTRICT,
    debit_minor INTEGER NOT NULL DEFAULT 0 CHECK(debit_minor >= 0), credit_minor INTEGER NOT NULL DEFAULT 0 CHECK(credit_minor >= 0),
    CHECK((debit_minor=0) <> (credit_minor=0))
  )''',
  'CREATE INDEX IF NOT EXISTS idx_gl_accounts_entity_parent ON gl_accounts(entity_id,parent_id)',
  'CREATE INDEX IF NOT EXISTS idx_gl_entries_entity_year_date ON gl_journal_entries(entity_id,financial_year_id,occurred_at)',
  'CREATE INDEX IF NOT EXISTS idx_gl_lines_entry ON gl_journal_lines(journal_entry_id)',
];

Future<void> createGeneralLedgerSchema(DatabaseExecutor db) =>
    executeStatements(db, generalLedgerSchemaStatements);
