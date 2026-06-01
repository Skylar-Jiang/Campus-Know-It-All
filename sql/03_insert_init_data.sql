USE campus_activity_db;

-- =========================================================
-- 1. Accounts
-- Passwords are all 123456 for classroom demonstration.
-- =========================================================

INSERT INTO user_account(username, password, role, phone) VALUES
('admin01', '123456', 'admin', '13800000001'),
('club01', '123456', 'club', '13800000002'),
('club02', '123456', 'club', '13800000003'),

('stu01', '123456', 'student', '13800000011'),
('stu02', '123456', 'student', '13800000012'),
('stu03', '123456', 'student', '13800000013'),
('stu04', '123456', 'student', '13800000014'),

('stu05', '123456', 'student', '13800000021'),
('stu06', '123456', 'student', '13800000022'),
('stu07', '123456', 'student', '13800000023'),
('stu08', '123456', 'student', '13800000024'),
('stu09', '123456', 'student', '13800000025');

SET @admin_id := (SELECT user_id FROM user_account WHERE username='admin01');
SET @club_music_user_id := (SELECT user_id FROM user_account WHERE username='club01');
SET @club_volunteer_user_id := (SELECT user_id FROM user_account WHERE username='club02');

SET @u_zhang := (SELECT user_id FROM user_account WHERE username='stu01');
SET @u_li := (SELECT user_id FROM user_account WHERE username='stu02');
SET @u_wang := (SELECT user_id FROM user_account WHERE username='stu03');
SET @u_zhao := (SELECT user_id FROM user_account WHERE username='stu04');
SET @u_confirm := (SELECT user_id FROM user_account WHERE username='stu05');
SET @u_wait := (SELECT user_id FROM user_account WHERE username='stu06');
SET @u_dup := (SELECT user_id FROM user_account WHERE username='stu07');
SET @u_low := (SELECT user_id FROM user_account WHERE username='stu08');
SET @u_fail := (SELECT user_id FROM user_account WHERE username='stu09');

-- =========================================================
-- 2. Clubs
-- =========================================================

INSERT INTO club(club_name, president_user_id, contact_phone, office_location) VALUES
('Music Club', @club_music_user_id, '13800010001', 'Building A-201'),
('Volunteer Club', @club_volunteer_user_id, '13800010002', 'Building B-105');

SET @club_music_id := (SELECT club_id FROM club WHERE club_name='Music Club');
SET @club_volunteer_id := (SELECT club_id FROM club WHERE club_name='Volunteer Club');

-- =========================================================
-- 3. Students
-- =========================================================

INSERT INTO student(user_id, student_no, real_name, grade, major, points, violation_count, credit_score) VALUES
(@u_zhang, '20230001', 'Zhang San', '2023', 'Computer Science', 10, 0, 100),
(@u_li, '20230002', 'Li Si', '2023', 'Software Engineering', 8, 0, 95),
(@u_wang, '20230003', 'Wang Wu', '2022', 'Data Science', 5, 0, 90),
(@u_zhao, '20230004', 'Zhao Liu', '2022', 'Automation', 6, 1, 88),

(@u_confirm, '20239901', 'Chen Yi', '2023', 'Computer Science', 0, 0, 100),
(@u_wait, '20239902', 'Sun Rui', '2023', 'Software Engineering', 0, 0, 100),
(@u_dup, '20239903', 'He Min', '2023', 'Data Science', 0, 0, 100),
(@u_low, '20239904', 'Lin Hao', '2023', 'Automation', 0, 3, 50),
(@u_fail, '20239905', 'Zhou Ning', '2023', 'Information Security', 0, 0, 100);

SET @s_zhang := (SELECT student_id FROM student WHERE user_id=@u_zhang);
SET @s_li := (SELECT student_id FROM student WHERE user_id=@u_li);
SET @s_wang := (SELECT student_id FROM student WHERE user_id=@u_wang);
SET @s_zhao := (SELECT student_id FROM student WHERE user_id=@u_zhao);
SET @s_confirm := (SELECT student_id FROM student WHERE user_id=@u_confirm);
SET @s_wait := (SELECT student_id FROM student WHERE user_id=@u_wait);
SET @s_dup := (SELECT student_id FROM student WHERE user_id=@u_dup);
SET @s_low := (SELECT student_id FROM student WHERE user_id=@u_low);
SET @s_fail := (SELECT student_id FROM student WHERE user_id=@u_fail);

-- =========================================================
-- 4. Venues
-- =========================================================

INSERT INTO venue(venue_name, capacity, location, status) VALUES
('Hall 101', 80, 'Teaching Building 1', 'available'),
('Playground East', 200, 'Sports Area', 'available'),
('Lecture Room C305', 120, 'Teaching Building 3', 'available'),
('Maker Space', 60, 'Innovation Center', 'available');

SET @venue_hall := (SELECT venue_id FROM venue WHERE venue_name='Hall 101');
SET @venue_playground := (SELECT venue_id FROM venue WHERE venue_name='Playground East');
SET @venue_lecture := (SELECT venue_id FROM venue WHERE venue_name='Lecture Room C305');
SET @venue_maker := (SELECT venue_id FROM venue WHERE venue_name='Maker Space');

-- =========================================================
-- 5. Activities
-- Number suffixes are for your private presentation order.
-- =========================================================

-- 01: Trigger normal insert, but activity is full, so new signup becomes waiting.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_hall, 'Campus Band Night 01', '音乐会',
  DATE_ADD(NOW(), INTERVAL 2 DAY),
  DATE_ADD(NOW(), INTERVAL 2 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 1 DAY),
  2, 'published',
  'Campus music performance and student interaction.'
);
SET @act_band := LAST_INSERT_ID();

-- 02: Trigger normal insert, enough capacity, new signup becomes confirmed.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_volunteer_id, @venue_playground, 'Weekend Cleaning Action 02', '志愿活动',
  DATE_ADD(NOW(), INTERVAL 3 DAY),
  DATE_ADD(NOW(), INTERVAL 3 DAY) + INTERVAL 3 HOUR,
  DATE_ADD(NOW(), INTERVAL 2 DAY),
  100, 'published',
  'Volunteer cleaning activity in campus public area.'
);
SET @act_weekend := LAST_INSERT_ID();

-- 03: Procedure success, can be finished because ongoing + end_time is in the past.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_lecture, 'Workshop Review 03', '培训',
  DATE_SUB(NOW(), INTERVAL 3 DAY),
  DATE_SUB(NOW(), INTERVAL 2 DAY),
  DATE_SUB(NOW(), INTERVAL 4 DAY),
  30, 'ongoing',
  'Workshop activity for attendance and resource settlement.'
);
SET @act_finish := LAST_INSERT_ID();

-- 04: Transactional delete success, cancelled and has linked data.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_volunteer_id, @venue_hall, 'Club Planning Meeting 04', '社团会议',
  DATE_ADD(NOW(), INTERVAL 10 DAY),
  DATE_ADD(NOW(), INTERVAL 10 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 9 DAY),
  20, 'cancelled',
  'Regular club planning meeting.'
);
SET @act_delete := LAST_INSERT_ID();

-- 05: Transactional delete failure, not cancelled.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_volunteer_id, @venue_hall, 'Campus Lecture 05', '讲座',
  DATE_ADD(NOW(), INTERVAL 6 DAY),
  DATE_ADD(NOW(), INTERVAL 6 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 5 DAY),
  40, 'published',
  'Public campus lecture.'
);
SET @act_delete_fail := LAST_INSERT_ID();

-- 06: Trigger failure, not published.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_maker, 'Innovation Salon 06', '讲座',
  DATE_ADD(NOW(), INTERVAL 7 DAY),
  DATE_ADD(NOW(), INTERVAL 7 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 6 DAY),
  30, 'draft',
  'Innovation salon activity not yet published.'
);
SET @act_draft := LAST_INSERT_ID();

-- 07: Trigger failure, deadline has passed.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_lecture, 'Career Talk 07', '培训',
  DATE_ADD(NOW(), INTERVAL 1 DAY),
  DATE_ADD(NOW(), INTERVAL 1 DAY) + INTERVAL 2 HOUR,
  DATE_SUB(NOW(), INTERVAL 1 HOUR),
  30, 'published',
  'Career planning talk with a closed signup deadline.'
);
SET @act_expired := LAST_INSERT_ID();

-- 08: Trigger failure, hot activity + low-credit student.
-- Category must be exactly 'hot' because the trigger checks v_category = 'hot'.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_hall, 'Hot Topic Forum 08', 'hot',
  DATE_ADD(NOW(), INTERVAL 5 DAY),
  DATE_ADD(NOW(), INTERVAL 5 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 4 DAY),
  10, 'published',
  'Forum for popular campus topics.'
);
SET @act_hot := LAST_INSERT_ID();

-- 09: Trigger failure, duplicate registration.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_maker, 'Reading Circle 09', '文化活动',
  DATE_ADD(NOW(), INTERVAL 8 DAY),
  DATE_ADD(NOW(), INTERVAL 8 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 7 DAY),
  30, 'published',
  'Reading and sharing activity.'
);
SET @act_duplicate := LAST_INSERT_ID();

-- 10: View query demo activity.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_volunteer_id, @venue_maker, 'Volunteer Resource Fair 10', '公益实践',
  DATE_ADD(NOW(), INTERVAL 12 DAY),
  DATE_ADD(NOW(), INTERVAL 12 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 11 DAY),
  50, 'published',
  'Volunteer resource fair for view-statistics display.'
);
SET @act_view := LAST_INSERT_ID();

-- 11: Optional waitlist promotion demo.
INSERT INTO activity(club_id, venue_id, title, category, start_time, end_time, signup_deadline, max_capacity, status, description)
VALUES (
  @club_music_id, @venue_hall, 'Club Meetup 11', '社团会议',
  DATE_ADD(NOW(), INTERVAL 9 DAY),
  DATE_ADD(NOW(), INTERVAL 9 DAY) + INTERVAL 2 HOUR,
  DATE_ADD(NOW(), INTERVAL 8 DAY),
  1, 'published',
  'Small meetup for optional waitlist promotion demo.'
);
SET @act_promote := LAST_INSERT_ID();

-- =========================================================
-- 6. Competitions
-- =========================================================

INSERT INTO competition(club_id, title, category, organizer, official_url, summary, start_time, end_time, status) VALUES
(@club_music_id, '全国大学生数学建模竞赛', '数学', '中国工业与应用数学学会', 'https://www.mcm.edu.cn/', '数学建模竞赛演示数据。', DATE_ADD(NOW(), INTERVAL 40 DAY), DATE_ADD(NOW(), INTERVAL 43 DAY), 'published'),
(@club_music_id, '中国大学生计算机设计大赛', '计算机', '中国大学生计算机设计大赛组织委员会', 'https://jsjds.blcu.edu.cn/', '计算机设计竞赛演示数据。', DATE_ADD(NOW(), INTERVAL 20 DAY), DATE_ADD(NOW(), INTERVAL 80 DAY), 'published'),
(@club_volunteer_id, '挑战杯全国大学生课外学术科技作品竞赛', '创新创业', '挑战杯组织委员会', 'https://www.tiaozhanbei.net/', '创新创业竞赛演示数据。', DATE_ADD(NOW(), INTERVAL 70 DAY), DATE_ADD(NOW(), INTERVAL 120 DAY), 'published');

-- =========================================================
-- 7. Shared resources
-- =========================================================

INSERT INTO resource_item(owner_club_id, item_name, category, total_qty, available_qty, unit, deposit_amount, status) VALUES
(@club_music_id, 'Speaker', 'audio', 10, 10, 'set', 200.00, 'available'),
(@club_music_id, 'Microphone', 'audio', 20, 20, 'piece', 50.00, 'available'),
(@club_volunteer_id, 'Trash Picker', 'tool', 50, 50, 'piece', 10.00, 'available'),
(@club_music_id, 'Projector', 'device', 6, 6, 'piece', 300.00, 'available'),
(@club_volunteer_id, 'Tent', 'outdoor', 10, 10, 'piece', 100.00, 'available');

SET @res_speaker := (SELECT resource_id FROM resource_item WHERE item_name='Speaker');
SET @res_microphone := (SELECT resource_id FROM resource_item WHERE item_name='Microphone');
SET @res_picker := (SELECT resource_id FROM resource_item WHERE item_name='Trash Picker');
SET @res_projector := (SELECT resource_id FROM resource_item WHERE item_name='Projector');
SET @res_tent := (SELECT resource_id FROM resource_item WHERE item_name='Tent');

-- =========================================================
-- 8. Registration data
-- NOTE: run this file before 04_trigger.sql.
-- =========================================================

-- 01: Campus Band Night 01 is already full and has one waiting.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_band, @s_zhang, DATE_SUB(NOW(), INTERVAL 1 DAY), 'approved', 'not_checked', 'confirmed', NULL),
(@act_band, @s_li, DATE_SUB(NOW(), INTERVAL 1 DAY), 'approved', 'not_checked', 'confirmed', NULL),
(@act_band, @s_wang, DATE_SUB(NOW(), INTERVAL 12 HOUR), 'approved', 'not_checked', 'waiting', 1);

-- 02: Weekend Cleaning Action 02 starts with one confirmed.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_weekend, @s_zhang, DATE_SUB(NOW(), INTERVAL 6 HOUR), 'approved', 'not_checked', 'confirmed', NULL);

-- 03: Workshop Review 03 has one checked and one absent student.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_finish, @s_zhang, DATE_SUB(NOW(), INTERVAL 5 DAY), 'approved', 'checked', 'confirmed', NULL);
SET @reg_finish_checked := LAST_INSERT_ID();

INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_finish, @s_li, DATE_SUB(NOW(), INTERVAL 5 DAY), 'approved', 'absent', 'confirmed', NULL);
SET @reg_finish_absent := LAST_INSERT_ID();

INSERT INTO checkin(reg_id, operator_id, status) VALUES
(@reg_finish_checked, @club_music_user_id, 'checked'),
(@reg_finish_absent, @club_music_user_id, 'absent');

-- 04: Club Planning Meeting 04 has linked data for transactional delete.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_delete, @s_zhao, DATE_SUB(NOW(), INTERVAL 1 DAY), 'approved', 'checked', 'confirmed', NULL);
SET @reg_delete := LAST_INSERT_ID();

INSERT INTO checkin(reg_id, operator_id, status)
VALUES(@reg_delete, @club_volunteer_user_id, 'checked');

-- 09: Reading Circle 09 already has stu07 registered.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_duplicate, @s_dup, DATE_SUB(NOW(), INTERVAL 1 HOUR), 'approved', 'not_checked', 'confirmed', NULL);

-- 10: View data.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_view, @s_zhang, DATE_SUB(NOW(), INTERVAL 2 HOUR), 'approved', 'checked', 'confirmed', NULL);
SET @reg_view_checked := LAST_INSERT_ID();

INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_view, @s_li, DATE_SUB(NOW(), INTERVAL 2 HOUR), 'approved', 'not_checked', 'confirmed', NULL);

INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_view, @s_wang, DATE_SUB(NOW(), INTERVAL 1 HOUR), 'approved', 'not_checked', 'waiting', 1);

INSERT INTO checkin(reg_id, operator_id, status)
VALUES(@reg_view_checked, @club_volunteer_user_id, 'checked');

-- 11: Optional waitlist promotion data.
INSERT INTO activity_registration(activity_id, student_id, register_time, audit_status, checkin_status, reg_status, queue_no)
VALUES
(@act_promote, @s_zhang, DATE_SUB(NOW(), INTERVAL 1 DAY), 'approved', 'not_checked', 'confirmed', NULL),
(@act_promote, @s_li, DATE_SUB(NOW(), INTERVAL 12 HOUR), 'approved', 'not_checked', 'waiting', 1),
(@act_promote, @s_wang, DATE_SUB(NOW(), INTERVAL 11 HOUR), 'approved', 'not_checked', 'waiting', 2);

-- =========================================================
-- 9. Borrow orders and details
-- =========================================================

-- 03: Overdue borrow order for procedure finish.
INSERT INTO borrow_order(activity_id, applicant_user_id, expected_return_time, order_status)
VALUES(@act_finish, @u_wang, DATE_SUB(NOW(), INTERVAL 1 DAY), 'borrowed');
SET @bo_finish_overdue := LAST_INSERT_ID();

INSERT INTO borrow_detail(order_id, resource_id, borrow_qty, returned_qty, damage_qty, compensation_amount)
VALUES
(@bo_finish_overdue, @res_speaker, 2, 0, 0, 0.00),
(@bo_finish_overdue, @res_projector, 1, 0, 0, 0.00);

UPDATE resource_item SET available_qty = available_qty - 2 WHERE resource_id = @res_speaker;
UPDATE resource_item SET available_qty = available_qty - 1 WHERE resource_id = @res_projector;

-- 04: Borrow order and penalty for transactional delete.
INSERT INTO borrow_order(activity_id, applicant_user_id, expected_return_time, order_status)
VALUES(@act_delete, @u_zhao, DATE_ADD(NOW(), INTERVAL 12 DAY), 'borrowed');
SET @bo_delete := LAST_INSERT_ID();

INSERT INTO borrow_detail(order_id, resource_id, borrow_qty, returned_qty, damage_qty, compensation_amount)
VALUES
(@bo_delete, @res_picker, 5, 0, 1, 10.00);

UPDATE resource_item SET available_qty = available_qty - 5 WHERE resource_id = @res_picker;

INSERT INTO penalty(student_id, activity_id, order_id, penalty_type, reason, amount, status)
VALUES(@s_zhao, @act_delete, @bo_delete, 'damage', 'Damage record for borrowed resource', 10.00, 'unpaid');

-- 10: Borrow data for view statistics.
INSERT INTO borrow_order(activity_id, applicant_user_id, expected_return_time, order_status)
VALUES(@act_view, @club_volunteer_user_id, DATE_ADD(NOW(), INTERVAL 13 DAY), 'borrowed');
SET @bo_view := LAST_INSERT_ID();

INSERT INTO borrow_detail(order_id, resource_id, borrow_qty, returned_qty, damage_qty, compensation_amount)
VALUES
(@bo_view, @res_tent, 3, 0, 0, 0.00);

UPDATE resource_item SET available_qty = available_qty - 3 WHERE resource_id = @res_tent;

-- =========================================================
-- 10. Final check output
-- =========================================================

SELECT 'DEMO DATA READY V2' AS message;

SELECT
  '01 trigger waitlist success' AS demo,
  @act_band AS activity_id,
  'Campus Band Night 01' AS title
UNION ALL
SELECT '02 trigger confirmed success', @act_weekend, 'Weekend Cleaning Action 02'
UNION ALL
SELECT '03 procedure finish success', @act_finish, 'Workshop Review 03'
UNION ALL
SELECT '04 transaction delete success', @act_delete, 'Club Planning Meeting 04'
UNION ALL
SELECT '05 transaction delete failure', @act_delete_fail, 'Campus Lecture 05'
UNION ALL
SELECT '06 trigger draft failure', @act_draft, 'Innovation Salon 06'
UNION ALL
SELECT '07 trigger expired failure', @act_expired, 'Career Talk 07'
UNION ALL
SELECT '08 trigger low credit failure', @act_hot, 'Hot Topic Forum 08'
UNION ALL
SELECT '09 trigger duplicate failure', @act_duplicate, 'Reading Circle 09'
UNION ALL
SELECT '10 view query demo', @act_view, 'Volunteer Resource Fair 10'
UNION ALL
SELECT '11 optional waitlist promote', @act_promote, 'Club Meetup 11';
