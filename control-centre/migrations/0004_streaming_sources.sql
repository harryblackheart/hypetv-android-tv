CREATE TABLE IF NOT EXISTS streaming_sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'xtream',
  display_name TEXT NOT NULL DEFAULT 'Primary Streaming Source',
  base_url TEXT NOT NULL,
  username_ciphertext TEXT NOT NULL,
  username_iv TEXT NOT NULL,
  password_ciphertext TEXT NOT NULL,
  password_iv TEXT NOT NULL,
  output_format TEXT NOT NULL DEFAULT 'm3u8',
  user_agent TEXT NOT NULL DEFAULT 'HypeTV',
  is_enabled INTEGER NOT NULL DEFAULT 1,
  last_tested_at TEXT,
  last_test_status TEXT,
  last_test_message TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_streaming_sources_customer_active ON streaming_sources(customer_id) WHERE is_enabled=1;
CREATE INDEX IF NOT EXISTS idx_streaming_sources_customer ON streaming_sources(customer_id);

CREATE TABLE IF NOT EXISTS catalogue_cache_v2 (
  cache_key TEXT PRIMARY KEY,
  source_id INTEGER NOT NULL,
  payload TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(source_id) REFERENCES streaming_sources(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_catalogue_cache_v2_expires ON catalogue_cache_v2(expires_at);

INSERT OR IGNORE INTO settings(key,value) VALUES
 ('catalogue_home_limit','20'),
 ('streaming_source_version','1');
