-- 00_reset_database.sql
-- Hard reset database for a fresh start (WARNING: this deletes all data)

DROP DATABASE IF EXISTS campus_activity_db;

CREATE DATABASE campus_activity_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE campus_activity_db;
