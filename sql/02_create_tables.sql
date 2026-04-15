-- 02_create_tables.sql
-- Core schema for Campus Activity & Shared Resource System

USE campus_activity_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS penalty;
DROP TABLE IF EXISTS borrow_detail;
DROP TABLE IF EXISTS borrow_order;
DROP TABLE IF EXISTS resource_item;
DROP TABLE IF EXISTS checkin;
DROP TABLE IF EXISTS activity_registration;
DROP TABLE IF EXISTS activity;
DROP TABLE IF EXISTS venue;
DROP TABLE IF EXISTS student;
DROP TABLE IF EXISTS club;
DROP TABLE IF EXISTS user_account;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE user_account (
  user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL,
  phone VARCHAR(20) NULL,
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (role IN ('admin', 'club', 'student'))
);

CREATE TABLE club (
  club_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  club_name VARCHAR(100) NOT NULL UNIQUE,
  president_user_id BIGINT NULL,
  contact_phone VARCHAR(20) NULL,
  office_location VARCHAR(100) NULL,
  CONSTRAINT fk_club_president
    FOREIGN KEY (president_user_id) REFERENCES user_account(user_id)
);

CREATE TABLE student (
  student_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL UNIQUE,
  student_no VARCHAR(30) NOT NULL UNIQUE,
  real_name VARCHAR(50) NOT NULL,
  grade VARCHAR(20) NULL,
  major VARCHAR(50) NULL,
  points INT NOT NULL DEFAULT 0,
  violation_count INT NOT NULL DEFAULT 0,
  credit_score INT NOT NULL DEFAULT 100,
  CONSTRAINT fk_student_user
    FOREIGN KEY (user_id) REFERENCES user_account(user_id),
  CHECK (credit_score BETWEEN 0 AND 120)
);

CREATE TABLE venue (
  venue_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  venue_name VARCHAR(100) NOT NULL,
  capacity INT NOT NULL,
  location VARCHAR(100) NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'available',
  CHECK (capacity > 0),
  CHECK (status IN ('available', 'unavailable'))
);

CREATE TABLE activity (
  activity_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  club_id BIGINT NOT NULL,
  venue_id BIGINT NOT NULL,
  title VARCHAR(200) NOT NULL,
  category VARCHAR(50) NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME NOT NULL,
  signup_deadline DATETIME NOT NULL,
  max_capacity INT NOT NULL,
  status VARCHAR(20) NOT NULL,
  description TEXT NULL,
  CONSTRAINT fk_activity_club
    FOREIGN KEY (club_id) REFERENCES club(club_id),
  CONSTRAINT fk_activity_venue
    FOREIGN KEY (venue_id) REFERENCES venue(venue_id),
  CHECK (end_time > start_time),
  CHECK (signup_deadline <= start_time),
  CHECK (max_capacity > 0),
  CHECK (status IN ('draft', 'published', 'ongoing', 'finished', 'cancelled'))
);

CREATE TABLE activity_registration (
  reg_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  activity_id BIGINT NOT NULL,
  student_id BIGINT NOT NULL,
  register_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  audit_status VARCHAR(20) NOT NULL DEFAULT 'approved',
  checkin_status VARCHAR(20) NOT NULL DEFAULT 'not_checked',
  reg_status VARCHAR(20) NOT NULL DEFAULT 'confirmed',
  queue_no INT NULL,
  CONSTRAINT fk_registration_activity
    FOREIGN KEY (activity_id) REFERENCES activity(activity_id),
  CONSTRAINT fk_registration_student
    FOREIGN KEY (student_id) REFERENCES student(student_id),
  UNIQUE KEY uq_activity_student (activity_id, student_id),
  CHECK (audit_status IN ('approved', 'rejected', 'pending')),
  CHECK (checkin_status IN ('not_checked', 'checked', 'absent')),
  CHECK (reg_status IN ('confirmed', 'waiting', 'cancelled')),
  CHECK (queue_no IS NULL OR queue_no > 0)
);

CREATE TABLE checkin (
  checkin_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  reg_id BIGINT NOT NULL,
  checkin_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  operator_id BIGINT NOT NULL,
  status VARCHAR(20) NOT NULL,
  CONSTRAINT fk_checkin_reg
    FOREIGN KEY (reg_id) REFERENCES activity_registration(reg_id),
  CONSTRAINT fk_checkin_operator
    FOREIGN KEY (operator_id) REFERENCES user_account(user_id),
  CHECK (status IN ('checked', 'absent'))
);

CREATE TABLE resource_item (
  resource_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  owner_club_id BIGINT NOT NULL,
  item_name VARCHAR(100) NOT NULL,
  category VARCHAR(50) NULL,
  total_qty INT NOT NULL,
  available_qty INT NOT NULL,
  unit VARCHAR(20) NOT NULL DEFAULT 'piece',
  deposit_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'available',
  CONSTRAINT fk_resource_owner_club
    FOREIGN KEY (owner_club_id) REFERENCES club(club_id),
  CHECK (total_qty >= 0),
  CHECK (available_qty >= 0),
  CHECK (available_qty <= total_qty),
  CHECK (status IN ('available', 'unavailable'))
);

CREATE TABLE borrow_order (
  order_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  activity_id BIGINT NOT NULL,
  applicant_user_id BIGINT NOT NULL,
  apply_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expected_return_time DATETIME NOT NULL,
  actual_return_time DATETIME NULL,
  order_status VARCHAR(20) NOT NULL,
  CONSTRAINT fk_borrow_activity
    FOREIGN KEY (activity_id) REFERENCES activity(activity_id),
  CONSTRAINT fk_borrow_applicant
    FOREIGN KEY (applicant_user_id) REFERENCES user_account(user_id),
  CHECK (order_status IN ('pending', 'approved', 'borrowed', 'returned', 'overdue'))
);

CREATE TABLE borrow_detail (
  detail_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  resource_id BIGINT NOT NULL,
  borrow_qty INT NOT NULL,
  returned_qty INT NOT NULL DEFAULT 0,
  damage_qty INT NOT NULL DEFAULT 0,
  compensation_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_borrow_detail_order
    FOREIGN KEY (order_id) REFERENCES borrow_order(order_id),
  CONSTRAINT fk_borrow_detail_resource
    FOREIGN KEY (resource_id) REFERENCES resource_item(resource_id),
  CHECK (borrow_qty > 0),
  CHECK (returned_qty >= 0),
  CHECK (damage_qty >= 0),
  CHECK (returned_qty <= borrow_qty),
  CHECK (damage_qty <= borrow_qty)
);

CREATE TABLE penalty (
  penalty_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  student_id BIGINT NULL,
  activity_id BIGINT NULL,
  order_id BIGINT NULL,
  penalty_type VARCHAR(30) NOT NULL,
  reason VARCHAR(200) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'unpaid',
  create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_penalty_student
    FOREIGN KEY (student_id) REFERENCES student(student_id),
  CONSTRAINT fk_penalty_activity
    FOREIGN KEY (activity_id) REFERENCES activity(activity_id),
  CONSTRAINT fk_penalty_order
    FOREIGN KEY (order_id) REFERENCES borrow_order(order_id),
  CHECK (penalty_type IN ('no_show', 'overdue', 'damage')),
  CHECK (status IN ('unpaid', 'paid', 'closed'))
);

CREATE TABLE audit_log (
  log_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  biz_type VARCHAR(30) NOT NULL,
  biz_id BIGINT NOT NULL,
  action VARCHAR(30) NOT NULL,
  operator_id BIGINT NULL,
  old_data JSON NULL,
  new_data JSON NULL,
  op_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_operator
    FOREIGN KEY (operator_id) REFERENCES user_account(user_id)
);

-- Recommended indexes for high-frequency queries
CREATE INDEX idx_activity_status_start
  ON activity(status, start_time);

CREATE INDEX idx_activity_registration_activity_status
  ON activity_registration(activity_id, reg_status);

CREATE INDEX idx_checkin_reg_status
  ON checkin(reg_id, status);

CREATE INDEX idx_borrow_order_status_expected
  ON borrow_order(order_status, expected_return_time);

CREATE INDEX idx_borrow_detail_order_resource
  ON borrow_detail(order_id, resource_id);

CREATE INDEX idx_penalty_student_status
  ON penalty(student_id, status);
