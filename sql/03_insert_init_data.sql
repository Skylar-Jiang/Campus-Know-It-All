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
