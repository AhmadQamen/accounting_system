import 'package:sqflite/sqflite.dart';
import 'schema_utils.dart';

const syncSchemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS sync_operations (
  id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  device_id TEXT,
  event_id TEXT,
  server_sequence INTEGER,
  operation_type TEXT NOT NULL,
  client_created_at TEXT NOT NULL,
  server_received_at TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  error_message TEXT
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_outbox (
  event_id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  aggregate_version INTEGER NOT NULL CHECK(aggregate_version > 0),
  occurred_at TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  server_sequence INTEGER,
  created_at TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  next_retry_at TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','syncing','accepted','conflict','rejected','failed')),
  UNIQUE(entity_id, aggregate_type, aggregate_id, aggregate_version)
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_changes (
  event_id TEXT PRIMARY KEY,
  entity_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  aggregate_version INTEGER NOT NULL,
  payload_json TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  received_at TEXT,
  applied_at TEXT NOT NULL,
  UNIQUE(entity_id, server_sequence)
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_cursors (
  entity_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  server_sequence INTEGER NOT NULL DEFAULT 0 CHECK(server_sequence >= 0),
  last_acknowledged_sequence INTEGER NOT NULL DEFAULT 0
    CHECK(last_acknowledged_sequence >= 0),
  updated_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_entity_state (
  entity_id TEXT PRIMARY KEY,
  device_id TEXT,
  device_revoked INTEGER NOT NULL DEFAULT 0 CHECK(device_revoked IN (0,1)),
  sync_enabled INTEGER NOT NULL DEFAULT 1 CHECK(sync_enabled IN (0,1)),
  bootstrap_completed INTEGER NOT NULL DEFAULT 0 CHECK(bootstrap_completed IN (0,1)),
  bootstrap_server_sequence INTEGER NOT NULL DEFAULT 0,
  last_sync_at TEXT,
  last_error TEXT,
  updated_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS sync_aggregate_versions (
  entity_id TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL,
  aggregate_version INTEGER NOT NULL CHECK(aggregate_version > 0),
  updated_at TEXT NOT NULL,
  PRIMARY KEY(entity_id, aggregate_type, aggregate_id)
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
  '''
CREATE TABLE IF NOT EXISTS legacy_sync_quarantine (
  operation_id TEXT PRIMARY KEY,
  entity_id TEXT,
  aggregate_type TEXT,
  aggregate_id TEXT,
  legacy_action TEXT,
  payload_json TEXT,
  legacy_status TEXT,
  legacy_created_at TEXT,
  quarantine_reason TEXT NOT NULL,
  quarantined_at TEXT NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS migration_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  migration_key TEXT NOT NULL,
  entity_id TEXT,
  affected_rows INTEGER NOT NULL DEFAULT 0,
  details TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''',
  'CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity_status ON sync_outbox(entity_id, status, next_retry_at)',
  'CREATE INDEX IF NOT EXISTS idx_sync_outbox_aggregate ON sync_outbox(entity_id, aggregate_type, aggregate_id)',
  'CREATE INDEX IF NOT EXISTS idx_sync_changes_sequence ON sync_changes(entity_id, server_sequence)',
  'CREATE INDEX IF NOT EXISTS idx_sync_changes_aggregate ON sync_changes(entity_id, aggregate_type, aggregate_id, aggregate_version)',
  'CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON sync_conflicts(entity_id, status)',
  'CREATE INDEX IF NOT EXISTS idx_legacy_sync_quarantine_entity ON legacy_sync_quarantine(entity_id, quarantined_at)',
];

Future<void> createSyncSchema(DatabaseExecutor db) =>
    executeStatements(db, syncSchemaStatements);
