-- HypeTV device registry, pairing and account sync foundation
ALTER TABLE devices ADD COLUMN model TEXT DEFAULT '';
ALTER TABLE devices ADD COLUMN os_version TEXT DEFAULT '';
ALTER TABLE devices ADD COLUMN active_profile_id TEXT DEFAULT '';
ALTER TABLE devices ADD COLUMN revoked_at TEXT;
ALTER TABLE devices ADD COLUMN updated_at TEXT;

-- New accounts are limited to three devices unless the owner raises the limit.
UPDATE packages SET device_limit=3 WHERE device_limit < 3;
UPDATE customers SET connection_allowance=3 WHERE connection_allowance < 3;

CREATE TABLE IF NOT EXISTS pairing_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  source_device_id INTEGER NOT NULL,
  code TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  claimed_device_id INTEGER,
  claimed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  FOREIGN KEY(source_device_id) REFERENCES devices(id) ON DELETE CASCADE,
  FOREIGN KEY(claimed_device_id) REFERENCES devices(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_pairing_customer ON pairing_sessions(customer_id, expires_at);

CREATE TABLE IF NOT EXISTS account_sync (
  customer_id INTEGER NOT NULL,
  sync_key TEXT NOT NULL,
  payload TEXT NOT NULL DEFAULT '{}',
  revision INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by_device_id INTEGER,
  PRIMARY KEY(customer_id, sync_key),
  FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  FOREIGN KEY(updated_by_device_id) REFERENCES devices(id) ON DELETE SET NULL
);


-- Backfill timestamps for existing rows after D1-compatible ALTER TABLE operations.
UPDATE devices SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL;
