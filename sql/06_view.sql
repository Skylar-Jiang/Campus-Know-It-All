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
