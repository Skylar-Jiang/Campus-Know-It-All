-- 10_add_borrow_order_uid.sql
-- Add UID-style borrow order identifier for existing databases

USE campus_activity_db;

SET @col_exists := (
  SELECT COUNT(1)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'borrow_order'
    AND column_name = 'order_uid'
);

SET @sql := IF(
  @col_exists = 0,
  'ALTER TABLE borrow_order ADD COLUMN order_uid VARCHAR(32) NULL UNIQUE AFTER order_id',
  'SELECT ''order_uid exists'''
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE borrow_order
SET order_uid = CONCAT('BOR-', DATE_FORMAT(apply_time, '%Y%m%d'), '-', LPAD(order_id, 6, '0'))
WHERE order_uid IS NULL;
