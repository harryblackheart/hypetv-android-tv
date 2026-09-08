-- HypeTV Control Centre v1.5.3
-- Repair databases where migration 0007 did not create device_limit.
ALTER TABLE customers ADD COLUMN device_limit INTEGER;
UPDATE customers SET device_limit = 3 WHERE device_limit IS NULL OR device_limit < 1;
