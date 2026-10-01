import 'package:sqflite/sqflite.dart';

import 'schema_utils.dart';

const currencySchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS currencies (
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  symbol TEXT NOT NULL,
  decimal_digits INTEGER NOT NULL DEFAULT 2 CHECK(decimal_digits BETWEEN 0 AND 4),
  is_base INTEGER NOT NULL DEFAULT 0 CHECK(is_base IN (0,1)),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(entity_id, code)
)
''',
  '''
CREATE TABLE IF NOT EXISTS exchange_rates (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
  currency_code TEXT NOT NULL,
  rate_micros INTEGER NOT NULL CHECK(rate_micros > 0),
  effective_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(entity_id, currency_code) REFERENCES currencies(entity_id, code) ON DELETE CASCADE
)
''',
  'CREATE INDEX IF NOT EXISTS idx_exchange_rates_latest ON exchange_rates(entity_id, currency_code, effective_at DESC, created_at DESC)',
];

Future<void> createCurrencySchema(DatabaseExecutor db) =>
    executeStatements(db, currencySchemaStatements);
