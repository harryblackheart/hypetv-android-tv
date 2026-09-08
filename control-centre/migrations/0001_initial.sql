CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  contact TEXT DEFAULT '',
  package_id INTEGER,
  expires_at TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  notes TEXT DEFAULT '',
  service_url TEXT DEFAULT '',
  service_username TEXT DEFAULT '',
  service_password TEXT DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS packages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  price_gbp REAL NOT NULL DEFAULT 0,
  device_limit INTEGER NOT NULL DEFAULT 1,
  description TEXT DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS activation_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  customer_id INTEGER NOT NULL,
  max_uses INTEGER NOT NULL DEFAULT 1,
  uses INTEGER NOT NULL DEFAULT 0,
  expires_at TEXT,
  revoked INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  device_id TEXT NOT NULL UNIQUE,
  device_name TEXT DEFAULT '',
  platform TEXT DEFAULT '',
  app_version TEXT DEFAULT '',
  last_seen TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  disabled INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS announcements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO packages (name, price_gbp, device_limit, description) VALUES
  ('Standard', 350, 1, 'One included box, single-device access'),
  ('MultiSub', 499, 3, 'One included box plus two additional connections'),
  ('Family', 599, 4, 'Four connections with two included boxes');

INSERT OR IGNORE INTO settings (key, value) VALUES
  ('platform_name', 'HypeTV'),
  ('tagline', 'How You Picture Entertainment'),
  ('version', '1.0.0');
