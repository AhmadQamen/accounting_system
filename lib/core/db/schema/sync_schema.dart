import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const syncSchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS sync_operations (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  device_id TEXT,
  user_id TEXT,
  operation_type TEXT NOT NULL,
  payload_hash TEXT,
  client_created_at TEXT NOT NULL,
  server_received_at TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','done','failed')),
  error_message TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_outbox (
  operation_id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  next_retry_at TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','syncing','done','failed'))
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_changes (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  server_seq INTEGER NOT NULL,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  change_type TEXT NOT NULL CHECK(change_type IN ('insert','update','delete')),
  record_version INTEGER NOT NULL,
  payload_json TEXT,
  changed_at TEXT NOT NULL,
  applied_at TEXT,
  UNIQUE(entity_id, server_seq)
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_conflicts (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  local_version INTEGER,
  server_version INTEGER,
  local_payload_json TEXT,
  server_payload_json TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved','ignored')),
  created_at TEXT NOT NULL,
  resolved_at TEXT
)
''',
  'CREATE INDEX IF NOT EXISTS idx_sync_outbox_status ON sync_outbox(status, next_retry_at)',
  'CREATE INDEX IF NOT EXISTS idx_sync_outbox_aggregate ON sync_outbox(aggregate_type, aggregate_id)',
  'CREATE INDEX IF NOT EXISTS idx_sync_changes_seq ON sync_changes(entity_id, server_seq)',
  'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON sync_conflicts(entity_id, status)',
];

Future<void> createSyncSchema(DatabaseExecutor db) =>
    executeStatements(db, syncSchemaStatements);
