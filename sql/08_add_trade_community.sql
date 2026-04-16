-- 08_add_trade_community.sql
-- Incremental schema for Campus All-in-One: Trade + Community

USE campus_activity_db;

-- =========================
-- Trade module
-- =========================

CREATE TABLE IF NOT EXISTS product_category (
  category_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_name VARCHAR(50) NOT NULL UNIQUE,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS product (
  product_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  seller_user_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  title VARCHAR(120) NOT NULL,
  description TEXT NULL,
  price DECIMAL(10, 2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'on_sale',
  publish_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_seller_user
    FOREIGN KEY (seller_user_id) REFERENCES user_account(user_id),
  CONSTRAINT fk_product_category
    FOREIGN KEY (category_id) REFERENCES product_category(category_id),
  CHECK (price >= 0),
  CHECK (status IN ('on_sale', 'locked', 'sold', 'removed'))
);

CREATE TABLE IF NOT EXISTS trade_order (
  order_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  buyer_user_id BIGINT NOT NULL,
  seller_user_id BIGINT NOT NULL,
  order_status VARCHAR(20) NOT NULL DEFAULT 'created',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finish_time DATETIME NULL,
  CONSTRAINT fk_trade_order_product
    FOREIGN KEY (product_id) REFERENCES product(product_id),
  CONSTRAINT fk_trade_order_buyer
    FOREIGN KEY (buyer_user_id) REFERENCES user_account(user_id),
  CONSTRAINT fk_trade_order_seller
    FOREIGN KEY (seller_user_id) REFERENCES user_account(user_id),
  CHECK (order_status IN ('created', 'cancelled', 'completed')),
  CHECK (buyer_user_id <> seller_user_id)
);

SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'product'
    AND index_name = 'idx_product_status_time'
);
SET @sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_product_status_time ON product(status, publish_time)',
  'SELECT ''idx_product_status_time exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'trade_order'
    AND index_name = 'idx_trade_order_buyer_status'
);
SET @sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_trade_order_buyer_status ON trade_order(buyer_user_id, order_status)',
  'SELECT ''idx_trade_order_buyer_status exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'trade_order'
    AND index_name = 'idx_trade_order_seller_status'
);
SET @sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_trade_order_seller_status ON trade_order(seller_user_id, order_status)',
  'SELECT ''idx_trade_order_seller_status exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- =========================
-- Community module
-- =========================

CREATE TABLE IF NOT EXISTS post_category (
  category_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_name VARCHAR(50) NOT NULL UNIQUE,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS post (
  post_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  author_user_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  title VARCHAR(150) NOT NULL,
  content TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'visible',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_post_author
    FOREIGN KEY (author_user_id) REFERENCES user_account(user_id),
  CONSTRAINT fk_post_category
    FOREIGN KEY (category_id) REFERENCES post_category(category_id),
  CHECK (status IN ('visible', 'hidden'))
);

CREATE TABLE IF NOT EXISTS post_comment (
  comment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  post_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  content VARCHAR(500) NOT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_comment_post
    FOREIGN KEY (post_id) REFERENCES post(post_id),
  CONSTRAINT fk_comment_user
    FOREIGN KEY (user_id) REFERENCES user_account(user_id)
);

SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'post'
    AND index_name = 'idx_post_status_time'
);
SET @sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_post_status_time ON post(status, create_time)',
  'SELECT ''idx_post_status_time exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'post_comment'
    AND index_name = 'idx_comment_post_time'
);
SET @sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_comment_post_time ON post_comment(post_id, create_time)',
  'SELECT ''idx_comment_post_time exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Seed categories only if empty
INSERT INTO product_category(category_name)
SELECT * FROM (
  SELECT 'books' AS category_name UNION ALL
  SELECT 'electronics' UNION ALL
  SELECT 'daily_goods'
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM product_category LIMIT 1);

INSERT INTO post_category(category_name)
SELECT * FROM (
  SELECT 'campus_life' AS category_name UNION ALL
  SELECT 'lost_found' UNION ALL
  SELECT 'experience_share'
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM post_category LIMIT 1);
