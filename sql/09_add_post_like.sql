-- 09_add_post_like.sql
-- Community like support

USE campus_activity_db;

CREATE TABLE IF NOT EXISTS post_like (
  like_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  post_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_post_like_post
    FOREIGN KEY (post_id) REFERENCES post(post_id),
  CONSTRAINT fk_post_like_user
    FOREIGN KEY (user_id) REFERENCES user_account(user_id),
  UNIQUE KEY uq_post_like_user (post_id, user_id)
);

CREATE INDEX idx_post_like_post ON post_like(post_id);
