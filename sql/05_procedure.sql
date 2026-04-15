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
