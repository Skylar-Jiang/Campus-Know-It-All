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
