-- 99_bootstrap_workbench.sql
-- Workbench-compatible full rebuild script (no SOURCE commands).


-- ===== BEGIN sql\00_reset_database.sql =====

-- 00_reset_database.sql
-- Hard reset database for a fresh start (WARNING: this deletes all data)

DROP DATABASE IF EXISTS campus_activity_db;

CREATE DATABASE campus_activity_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE campus_activity_db;

-- ===== END sql\00_reset_database.sql =====


-- ===== BEGIN sql\02_create_tables.sql =====

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
  order_uid VARCHAR(32) NULL UNIQUE,
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

-- ===== END sql\02_create_tables.sql =====


-- ===== BEGIN sql\03_insert_init_data.sql =====

-- 03_insert_init_data.sql
-- Minimal demo data for quick validation

USE campus_activity_db;

-- Users
INSERT INTO user_account(username, password, role, phone) VALUES
('admin1', '123456', 'admin', '13800000001'),
('club_music', '123456', 'club', '13800000002'),
('club_volunteer', '123456', 'club', '13800000003'),
('stu_zhang', '123456', 'student', '13800000011'),
('stu_li', '123456', 'student', '13800000012'),
('stu_wang', '123456', 'student', '13800000013'),
('stu_zhao', '123456', 'student', '13800000014');

-- Clubs
INSERT INTO club(club_name, president_user_id, contact_phone, office_location) VALUES
('Music Club', 2, '13800010001', 'Building A-201'),
('Volunteer Club', 3, '13800010002', 'Building B-105');

-- Students
INSERT INTO student(user_id, student_no, real_name, grade, major) VALUES
(4, '20230001', 'Zhang San', '2023', 'Computer Science'),
(5, '20230002', 'Li Si', '2023', 'Software Engineering'),
(6, '20230003', 'Wang Wu', '2022', 'Data Science'),
(7, '20230004', 'Zhao Liu', '2022', 'Automation');

-- Venues
INSERT INTO venue(venue_name, capacity, location, status) VALUES
('Hall 101', 80, 'Teaching Building 1', 'available'),
('Playground East', 200, 'Sports Area', 'available'),
('Lecture Room C305', 120, 'Teaching Building 3', 'available');

-- Activities
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description) VALUES
(1, 1, 'Campus Band Night', 'culture', DATE_ADD(NOW(), INTERVAL 2 DAY), DATE_ADD(NOW(), INTERVAL 2 DAY) + INTERVAL 2 HOUR, DATE_ADD(NOW(), INTERVAL 1 DAY), 2, 'published', 'Night music performance and interaction'),
(2, 2, 'Weekend Cleaning Action', 'public_service', DATE_ADD(NOW(), INTERVAL 3 DAY), DATE_ADD(NOW(), INTERVAL 3 DAY) + INTERVAL 3 HOUR, DATE_ADD(NOW(), INTERVAL 2 DAY), 100, 'published', 'Volunteer cleaning in campus public area'),
(1, 3, 'Old Activity For Finish Demo', 'training', DATE_SUB(NOW(), INTERVAL 3 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY), 30, 'ongoing', 'Used to demo finish procedure'),
(2, 1, 'Cancelled Activity For Delete Demo', 'meeting', DATE_ADD(NOW(), INTERVAL 10 DAY), DATE_ADD(NOW(), INTERVAL 10 DAY) + INTERVAL 2 HOUR, DATE_ADD(NOW(), INTERVAL 9 DAY), 20, 'cancelled', 'Used to demo transactional delete');

-- Shared resources
INSERT INTO resource_item(owner_club_id, item_name, category, total_qty, available_qty, unit, deposit_amount, status) VALUES
(1, 'Speaker', 'audio', 10, 10, 'set', 200.00, 'available'),
(1, 'Microphone', 'audio', 20, 20, 'piece', 50.00, 'available'),
(2, 'Trash Picker', 'tool', 50, 50, 'piece', 10.00, 'available');

-- Borrow order and details for demo
INSERT INTO borrow_order(activity_id, applicant_user_id, expected_return_time, order_status)
VALUES (1, 2, DATE_ADD(NOW(), INTERVAL 4 DAY), 'borrowed');

INSERT INTO borrow_detail(order_id, resource_id, borrow_qty, returned_qty, damage_qty, compensation_amount)
VALUES
(1, 1, 2, 0, 0, 0),
(1, 2, 4, 0, 0, 0);

UPDATE resource_item SET available_qty = available_qty - 2 WHERE resource_id = 1;
UPDATE resource_item SET available_qty = available_qty - 4 WHERE resource_id = 2;

-- Registrations (activity_id=1 has max_capacity=2, used to test waitlist)
INSERT INTO activity_registration(activity_id, student_id, reg_status, queue_no) VALUES (1, 1, 'confirmed', NULL);
INSERT INTO activity_registration(activity_id, student_id, reg_status, queue_no) VALUES (1, 2, 'confirmed', NULL);
INSERT INTO activity_registration(activity_id, student_id, reg_status, queue_no) VALUES (1, 3, 'waiting', 1);

-- Finished-procedure demo registrations for activity_id=3
INSERT INTO activity_registration(activity_id, student_id, register_time, reg_status, checkin_status)
VALUES
(3, 1, DATE_SUB(NOW(), INTERVAL 5 DAY), 'confirmed', 'checked'),
(3, 2, DATE_SUB(NOW(), INTERVAL 5 DAY), 'confirmed', 'absent');

-- Checkin rows for activity_id=3
INSERT INTO checkin(reg_id, operator_id, status)
SELECT reg_id, 2, checkin_status
FROM activity_registration
WHERE activity_id = 3;

-- ===== END sql\03_insert_init_data.sql =====


-- ===== BEGIN sql\04_trigger.sql =====

-- 04_trigger.sql
-- Trigger set: registration control + audit logs

USE campus_activity_db;

DROP TRIGGER IF EXISTS trg_before_insert_registration;
DROP TRIGGER IF EXISTS trg_after_update_borrow_order_audit;
DROP TRIGGER IF EXISTS trg_after_update_activity_audit;

DELIMITER $$

CREATE TRIGGER trg_before_insert_registration
BEFORE INSERT ON activity_registration
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_deadline DATETIME;
  DECLARE v_capacity INT;
  DECLARE v_confirmed_count INT DEFAULT 0;
  DECLARE v_waiting_max INT;
  DECLARE v_credit INT;
  DECLARE v_category VARCHAR(50);

  -- 1) activity must exist and be published
  SELECT status, signup_deadline, max_capacity, category
    INTO v_status, v_deadline, v_capacity, v_category
  FROM activity
  WHERE activity_id = NEW.activity_id;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity does not exist';
  END IF;

  IF v_status <> 'published' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity is not published';
  END IF;

  IF NOW() > v_deadline THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Signup deadline has passed';
  END IF;

  -- 2) duplicate registration check (friendly error)
  IF EXISTS (
    SELECT 1
    FROM activity_registration
    WHERE activity_id = NEW.activity_id
      AND student_id = NEW.student_id
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Duplicate registration is not allowed';
  END IF;

  -- 3) optional rule: low credit cannot join hot category
  SELECT credit_score INTO v_credit
  FROM student
  WHERE student_id = NEW.student_id;

  IF v_category = 'hot' AND v_credit < 60 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Credit score too low for hot activity';
  END IF;

  -- 4) fill confirmed first; overflow goes to waitlist
  SELECT COUNT(*) INTO v_confirmed_count
  FROM activity_registration
  WHERE activity_id = NEW.activity_id
    AND reg_status = 'confirmed';

  IF v_confirmed_count < v_capacity THEN
    SET NEW.reg_status = 'confirmed';
    SET NEW.queue_no = NULL;
  ELSE
    SET NEW.reg_status = 'waiting';

    SELECT COALESCE(MAX(queue_no), 0)
      INTO v_waiting_max
    FROM activity_registration
    WHERE activity_id = NEW.activity_id
      AND reg_status = 'waiting';

    SET NEW.queue_no = v_waiting_max + 1;
  END IF;
END $$

CREATE TRIGGER trg_after_update_borrow_order_audit
AFTER UPDATE ON borrow_order
FOR EACH ROW
BEGIN
  IF OLD.order_status <> NEW.order_status THEN
    INSERT INTO audit_log(biz_type, biz_id, action, operator_id, old_data, new_data)
    VALUES (
      'borrow_order',
      NEW.order_id,
      'status_change',
      NEW.applicant_user_id,
      JSON_OBJECT('order_status', OLD.order_status, 'actual_return_time', OLD.actual_return_time),
      JSON_OBJECT('order_status', NEW.order_status, 'actual_return_time', NEW.actual_return_time)
    );
  END IF;
END $$

CREATE TRIGGER trg_after_update_activity_audit
AFTER UPDATE ON activity
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status THEN
    INSERT INTO audit_log(biz_type, biz_id, action, operator_id, old_data, new_data)
    VALUES (
      'activity',
      NEW.activity_id,
      'status_change',
      NULL,
      JSON_OBJECT('status', OLD.status),
      JSON_OBJECT('status', NEW.status)
    );
  END IF;
END $$

DELIMITER ;

-- ===== END sql\04_trigger.sql =====


-- ===== BEGIN sql\05_procedure.sql =====

-- 05_procedure.sql
-- Procedures: finish activity, transactional delete, promote waitlist

USE campus_activity_db;

DROP PROCEDURE IF EXISTS sp_finish_activity;
DROP PROCEDURE IF EXISTS sp_delete_cancelled_activity;
DROP PROCEDURE IF EXISTS sp_promote_waitlist;

DELIMITER $$

CREATE PROCEDURE sp_promote_waitlist(IN p_activity_id BIGINT)
proc_promote: BEGIN
  DECLARE v_reg_id BIGINT;

  START TRANSACTION;

  SELECT reg_id
    INTO v_reg_id
  FROM activity_registration
  WHERE activity_id = p_activity_id
    AND reg_status = 'waiting'
  ORDER BY queue_no ASC
  LIMIT 1
  FOR UPDATE;

  IF v_reg_id IS NULL THEN
    COMMIT;
    LEAVE proc_promote;
  END IF;

  UPDATE activity_registration
  SET reg_status = 'confirmed', queue_no = NULL
  WHERE reg_id = v_reg_id;

  -- Re-number remaining waiting queue
  SET @rownum := 0;
  UPDATE activity_registration ar
  JOIN (
    SELECT reg_id, (@rownum := @rownum + 1) AS new_queue_no
    FROM activity_registration
    WHERE activity_id = p_activity_id AND reg_status = 'waiting'
    ORDER BY queue_no ASC, reg_id ASC
  ) q ON ar.reg_id = q.reg_id
  SET ar.queue_no = q.new_queue_no;

  COMMIT;
END $$

CREATE PROCEDURE sp_finish_activity(IN p_activity_id BIGINT)
proc_finish: BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_end_time DATETIME;

  START TRANSACTION;

  SELECT status, end_time
    INTO v_status, v_end_time
  FROM activity
  WHERE activity_id = p_activity_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity not found';
  END IF;

  IF v_status <> 'ongoing' THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only ongoing activity can be finished';
  END IF;

  IF NOW() < v_end_time THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity has not reached end_time yet';
  END IF;

  UPDATE activity
  SET status = 'finished'
  WHERE activity_id = p_activity_id;

  -- Reward checked students
  UPDATE student s
  JOIN activity_registration ar ON ar.student_id = s.student_id
  SET s.points = s.points + 5,
      s.credit_score = LEAST(120, s.credit_score + 1)
  WHERE ar.activity_id = p_activity_id
    AND ar.reg_status = 'confirmed'
    AND ar.checkin_status = 'checked';

  -- Penalize absentees
  UPDATE student s
  JOIN activity_registration ar ON ar.student_id = s.student_id
  SET s.violation_count = s.violation_count + 1,
      s.credit_score = GREATEST(0, s.credit_score - 5)
  WHERE ar.activity_id = p_activity_id
    AND ar.reg_status = 'confirmed'
    AND ar.checkin_status <> 'checked';

  INSERT INTO penalty(student_id, activity_id, penalty_type, reason, amount, status)
  SELECT ar.student_id,
         p_activity_id,
         'no_show',
         'Absent after successful registration',
         0,
         'closed'
  FROM activity_registration ar
  WHERE ar.activity_id = p_activity_id
    AND ar.reg_status = 'confirmed'
    AND ar.checkin_status <> 'checked';

  -- Mark borrowed orders as overdue when expected_return_time passed
  UPDATE borrow_order bo
  SET bo.order_status = 'overdue'
  WHERE bo.activity_id = p_activity_id
    AND bo.order_status = 'borrowed'
    AND bo.expected_return_time < NOW();

  -- Student penalty for overdue borrow orders
  INSERT INTO penalty(student_id, activity_id, order_id, penalty_type, reason, amount, status)
  SELECT DISTINCT st.student_id,
         bo.activity_id,
         bo.order_id,
         'overdue',
         'Resource overdue return',
         0,
         'unpaid'
  FROM borrow_order bo
  JOIN user_account ua ON ua.user_id = bo.applicant_user_id
  JOIN student st ON st.user_id = ua.user_id
  WHERE bo.activity_id = p_activity_id
    AND bo.order_status = 'overdue';

  UPDATE student s
  JOIN user_account ua ON ua.user_id = s.user_id
  JOIN borrow_order bo ON bo.applicant_user_id = ua.user_id
  SET s.credit_score = GREATEST(0, s.credit_score - 8)
  WHERE bo.activity_id = p_activity_id
    AND bo.order_status = 'overdue';

  COMMIT;
END $$

CREATE PROCEDURE sp_delete_cancelled_activity(IN p_activity_id BIGINT)
proc_delete: BEGIN
  DECLARE v_status VARCHAR(20);

  START TRANSACTION;

  SELECT status INTO v_status
  FROM activity
  WHERE activity_id = p_activity_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity not found';
  END IF;

  IF v_status <> 'cancelled' THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only cancelled activity can be deleted';
  END IF;

  DELETE c
  FROM checkin c
  JOIN activity_registration ar ON ar.reg_id = c.reg_id
  WHERE ar.activity_id = p_activity_id;

  DELETE FROM penalty
  WHERE activity_id = p_activity_id
     OR order_id IN (
       SELECT order_id FROM borrow_order WHERE activity_id = p_activity_id
     );

  DELETE bd
  FROM borrow_detail bd
  JOIN borrow_order bo ON bo.order_id = bd.order_id
  WHERE bo.activity_id = p_activity_id;

  DELETE FROM borrow_order
  WHERE activity_id = p_activity_id;

  DELETE FROM activity_registration
  WHERE activity_id = p_activity_id;

  DELETE FROM activity
  WHERE activity_id = p_activity_id;

  COMMIT;
END $$

DELIMITER ;

-- ===== END sql\05_procedure.sql =====


-- ===== BEGIN sql\06_view.sql =====

-- 06_view.sql
-- Reporting views for demo and dashboard

USE campus_activity_db;

DROP VIEW IF EXISTS v_activity_summary;
DROP VIEW IF EXISTS v_hot_activity_top10;
DROP VIEW IF EXISTS v_club_resource_utilization;

CREATE VIEW v_activity_summary AS
SELECT
  a.activity_id,
  a.title AS activity_title,
  c.club_name,
  v.venue_name,
  a.status,
  COALESCE(r.confirmed_count, 0) AS confirmed_count,
  COALESCE(r.waiting_count, 0) AS waiting_count,
  COALESCE(r.checked_count, 0) AS checked_count,
  COALESCE(b.borrow_total_qty, 0) AS borrow_total_qty
FROM activity a
JOIN club c ON c.club_id = a.club_id
JOIN venue v ON v.venue_id = a.venue_id
LEFT JOIN (
  SELECT
    activity_id,
    COUNT(CASE WHEN reg_status = 'confirmed' THEN 1 END) AS confirmed_count,
    COUNT(CASE WHEN reg_status = 'waiting' THEN 1 END) AS waiting_count,
    COUNT(CASE WHEN checkin_status = 'checked' THEN 1 END) AS checked_count
  FROM activity_registration
  GROUP BY activity_id
) r ON r.activity_id = a.activity_id
LEFT JOIN (
  SELECT
    bo.activity_id,
    SUM(bd.borrow_qty) AS borrow_total_qty
  FROM borrow_order bo
  JOIN borrow_detail bd ON bd.order_id = bo.order_id
  GROUP BY bo.activity_id
) b ON b.activity_id = a.activity_id;

CREATE VIEW v_hot_activity_top10 AS
SELECT
  t.activity_id,
  t.activity_title,
  t.club_name,
  t.confirmed_count,
  t.checked_count,
  ROUND(
    CASE WHEN t.confirmed_count = 0 THEN 0
         ELSE t.checked_count / t.confirmed_count * 100
    END,
    2
  ) AS checkin_rate_pct
FROM v_activity_summary t
ORDER BY t.confirmed_count DESC, checkin_rate_pct DESC
LIMIT 10;

CREATE VIEW v_club_resource_utilization AS
SELECT
  c.club_id,
  c.club_name,
  COALESCE(SUM(bd.borrow_qty), 0) AS total_borrow_qty,
  COALESCE(SUM(bd.damage_qty), 0) AS total_damage_qty,
  ROUND(
    CASE WHEN COALESCE(SUM(bd.borrow_qty), 0) = 0 THEN 0
         ELSE COALESCE(SUM(bd.damage_qty), 0) / SUM(bd.borrow_qty) * 100
    END,
    2
  ) AS damage_rate_pct,
  ROUND(
    AVG(CASE WHEN bo.order_status = 'overdue' THEN 1 ELSE 0 END) * 100,
    2
  ) AS overdue_rate_pct
FROM club c
LEFT JOIN activity a ON a.club_id = c.club_id
LEFT JOIN borrow_order bo ON bo.activity_id = a.activity_id
LEFT JOIN borrow_detail bd ON bd.order_id = bo.order_id
GROUP BY c.club_id, c.club_name;

-- ===== END sql\06_view.sql =====


-- ===== BEGIN sql\07_event.sql =====

-- 07_event.sql
-- Scheduled overdue checker (MySQL Event)

USE campus_activity_db;

SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS ev_mark_overdue_orders;

DELIMITER $$

CREATE EVENT ev_mark_overdue_orders
ON SCHEDULE EVERY 30 MINUTE
DO
BEGIN
  -- Mark overdue orders
  UPDATE borrow_order
  SET order_status = 'overdue'
  WHERE order_status = 'borrowed'
    AND expected_return_time < NOW();

  -- Insert overdue penalties if not exists
  INSERT INTO penalty(student_id, activity_id, order_id, penalty_type, reason, amount, status)
  SELECT st.student_id,
         bo.activity_id,
         bo.order_id,
         'overdue',
         'Resource overdue return (event)',
         0,
         'unpaid'
  FROM borrow_order bo
  JOIN user_account ua ON ua.user_id = bo.applicant_user_id
  JOIN student st ON st.user_id = ua.user_id
  WHERE bo.order_status = 'overdue'
    AND NOT EXISTS (
      SELECT 1
      FROM penalty p
      WHERE p.order_id = bo.order_id
        AND p.penalty_type = 'overdue'
    );
END $$

DELIMITER ;

-- ===== END sql\07_event.sql =====


-- ===== BEGIN sql\08_add_trade_community.sql =====

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

-- ===== END sql\08_add_trade_community.sql =====


-- ===== BEGIN sql\09_add_post_like.sql =====

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

SET @idx_exists := (
  SELECT COUNT(1)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'post_like'
    AND index_name = 'idx_post_like_post'
);
SET @sql := IF(
  @idx_exists = 0,
  'CREATE INDEX idx_post_like_post ON post_like(post_id)',
  'SELECT ''idx_post_like_post exists'''
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ===== END sql\09_add_post_like.sql =====

