CREATE TABLE IF NOT EXISTS streaming_source_presets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  base_url TEXT NOT NULL,
  output_format TEXT NOT NULL DEFAULT 'm3u8',
  user_agent TEXT NOT NULL DEFAULT 'HypeTV',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO streaming_source_presets(name,base_url,output_format,user_agent,active)
SELECT 'HypeTVB', base_url, output_format, user_agent, 1
FROM streaming_sources
WHERE base_url IS NOT NULL AND base_url <> ''
ORDER BY id DESC LIMIT 1;
