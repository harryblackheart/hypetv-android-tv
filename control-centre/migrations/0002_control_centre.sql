ALTER TABLE customers ADD COLUMN connection_allowance INTEGER NOT NULL DEFAULT 1;
ALTER TABLE customers ADD COLUMN package_label TEXT DEFAULT '';

ALTER TABLE devices ADD COLUMN token_hash TEXT;
ALTER TABLE devices ADD COLUMN registered_at TEXT;
UPDATE devices SET registered_at = COALESCE(registered_at, last_seen, CURRENT_TIMESTAMP);
ALTER TABLE devices ADD COLUMN status TEXT NOT NULL DEFAULT 'active';
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_token_hash ON devices(token_hash) WHERE token_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_devices_customer ON devices(customer_id, disabled);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal' CHECK(priority IN ('normal','important','critical')),
  target_type TEXT NOT NULL DEFAULT 'everyone' CHECK(target_type IN ('everyone','customer','device')),
  target_customer_id INTEGER,
  target_device_id INTEGER,
  expires_at TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(target_customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  FOREIGN KEY(target_device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS message_receipts (
  message_id INTEGER NOT NULL,
  device_id INTEGER NOT NULL,
  delivered_at TEXT,
  read_at TEXT,
  PRIMARY KEY(message_id, device_id),
  FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE,
  FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS rate_limits (
  bucket TEXT PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 0,
  window_start INTEGER NOT NULL
);

INSERT OR IGNORE INTO settings(key,value) VALUES
 ('maintenance_enabled','false'),
 ('maintenance_message',''),
 ('maintenance_estimated_return','');

UPDATE customers
SET connection_allowance = COALESCE(
  (SELECT device_limit FROM packages WHERE packages.id = customers.package_id),
  1
)
WHERE connection_allowance IS NULL OR connection_allowance < 1;
