ALTER TABLE customers ADD COLUMN service_output TEXT NOT NULL DEFAULT 'm3u8';
ALTER TABLE customers ADD COLUMN service_last_tested_at TEXT;
ALTER TABLE customers ADD COLUMN service_last_status TEXT;
ALTER TABLE customers ADD COLUMN service_last_error TEXT;

CREATE TABLE IF NOT EXISTS catalogue_cache (
  cache_key TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_catalogue_cache_expires ON catalogue_cache(expires_at);

INSERT OR IGNORE INTO settings(key,value) VALUES
 ('catalogue_cache_seconds','300');
