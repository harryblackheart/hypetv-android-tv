ALTER TABLE customers ADD COLUMN content_access TEXT NOT NULL DEFAULT 'hype_only';
CREATE INDEX IF NOT EXISTS idx_customers_content_access ON customers(content_access);
