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
