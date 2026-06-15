-- ============================================================
--  TTD  |  Final Database Schema
--  Run this file to set up complete database
-- ============================================================

DROP DATABASE IF EXISTS ttd;
CREATE DATABASE ttd;
USE ttd;

-- ============================================================
-- TABLE 1: USERS
-- ============================================================
CREATE TABLE USERS (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    email          VARCHAR(255) UNIQUE NOT NULL,
    phone_number   VARCHAR(15) NOT NULL,
    aadhar_number  VARCHAR(12) UNIQUE,
    passport_number VARCHAR(20) UNIQUE,
    country        VARCHAR(50) DEFAULT 'India',
    password       VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_status    ENUM('active','inactive','suspended') DEFAULT 'active',
    CHECK (aadhar_number IS NOT NULL OR passport_number IS NOT NULL),
    CHECK (aadhar_number IS NULL OR CHAR_LENGTH(aadhar_number) = 12),
    CHECK (passport_number IS NULL OR passport_number REGEXP '^[A-Z][0-9]{7}$')
);


-- ============================================================
-- TABLE 3: DARSHAN_TYPE
-- ============================================================
CREATE TABLE DARSHAN_TYPE (
    darshan_type_id INT AUTO_INCREMENT PRIMARY KEY,
    darshan_name    VARCHAR(100) NOT NULL,
    price           DECIMAL(10,2) NOT NULL
);

-- ============================================================
-- TABLE 4: TIME_SLOT
-- ============================================================
CREATE TABLE TIME_SLOT (
    time_slot_id    INT AUTO_INCREMENT PRIMARY KEY,
    darshan_type_id INT,
    darshan_date    DATE NOT NULL,
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    max_capacity    INT NOT NULL,
    booked_count    INT DEFAULT 0,
    slot_type       ENUM('indian','nri') DEFAULT 'indian',
    FOREIGN KEY (darshan_type_id) REFERENCES DARSHAN_TYPE(darshan_type_id),
    CHECK (end_time > start_time)
);

-- ============================================================
-- TABLE 5: ACCOMMODATION
-- ============================================================
CREATE TABLE ACCOMMODATION (
    room_id       INT AUTO_INCREMENT PRIMARY KEY,
    room_type     VARCHAR(100) NOT NULL,
    capacity      INT NOT NULL,
    price_per_day DECIMAL(10,2) NOT NULL
);

-- ============================================================
-- TABLE 6: DARSHAN_BOOKING
-- ============================================================
CREATE TABLE DARSHAN_BOOKING (
    booking_id        INT AUTO_INCREMENT PRIMARY KEY,
    booking_reference VARCHAR(20) UNIQUE,
    user_id           INT,
    time_slot_id      INT,
    number_of_persons INT,
    booking_type      ENUM('indian','nri'),
    booking_status    ENUM('confirmed','cancelled','pending') DEFAULT 'pending',
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)      REFERENCES USERS(user_id)     ON DELETE CASCADE,
    FOREIGN KEY (time_slot_id) REFERENCES TIME_SLOT(time_slot_id) ON DELETE CASCADE
);

-- ============================================================
-- TABLE 7: PILGRIM_DETAILS
-- ============================================================
CREATE TABLE PILGRIM_DETAILS (
    pilgrim_id      INT AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT,
    pilgrim_name    VARCHAR(100),
    age             INT,
    gender          ENUM('Male','Female','Other'),
    aadhar_number   VARCHAR(12),
    passport_number VARCHAR(20),
    country         VARCHAR(50) DEFAULT 'India',
    CHECK (aadhar_number IS NOT NULL OR passport_number IS NOT NULL),
    CHECK (aadhar_number IS NULL OR CHAR_LENGTH(aadhar_number) = 12),
    FOREIGN KEY (booking_id) REFERENCES DARSHAN_BOOKING(booking_id) ON DELETE CASCADE
);

-- ============================================================
-- TABLE 8: ROOM_BOOKING
-- ============================================================
CREATE TABLE ROOM_BOOKING (
    room_booking_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT,
    user_id         INT,
    room_id         INT,
    check_in_date   DATE,
    check_out_date  DATE,
    booking_status  ENUM('confirmed','cancelled','pending') DEFAULT 'pending',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (check_out_date > check_in_date),
    FOREIGN KEY (booking_id) REFERENCES DARSHAN_BOOKING(booking_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES USERS(user_id),
    FOREIGN KEY (room_id)    REFERENCES ACCOMMODATION(room_id)
);

-- ============================================================
-- TABLE 9: PAYMENT
-- ============================================================
CREATE TABLE PAYMENT (
    payment_id      INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id  VARCHAR(100),
    user_id         INT,
    booking_id      INT,
    room_booking_id INT,
    amount          DECIMAL(10,2),
    payment_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_status  ENUM('success','failed','pending') DEFAULT 'pending',
    payment_method  ENUM('upi','netbanking','debit_card','credit_card','wallet'),
    FOREIGN KEY (user_id)         REFERENCES USERS(user_id),
    FOREIGN KEY (booking_id)      REFERENCES DARSHAN_BOOKING(booking_id),
    FOREIGN KEY (room_booking_id) REFERENCES ROOM_BOOKING(room_booking_id)
);

-- ============================================================
-- TABLE 10: DONATION
-- ============================================================
CREATE TABLE DONATION (
    donation_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT,
    amount        DECIMAL(10,2),
    donation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    donation_type VARCHAR(50),
    FOREIGN KEY (user_id) REFERENCES USERS(user_id)
);

-- ============================================================
-- TRIGGERS
-- ============================================================
DELIMITER $$

-- Trigger 1: Increment booked_count when a booking is confirmed
CREATE TRIGGER trg_increment_booked
AFTER UPDATE ON DARSHAN_BOOKING
FOR EACH ROW
BEGIN
    IF NEW.booking_status = 'confirmed' AND OLD.booking_status != 'confirmed' THEN
        UPDATE TIME_SLOT
        SET booked_count = booked_count + NEW.number_of_persons
        WHERE time_slot_id = NEW.time_slot_id;
    END IF;
END$$

-- Trigger 2: Decrement booked_count when a booking is cancelled
CREATE TRIGGER trg_decrement_booked
AFTER UPDATE ON DARSHAN_BOOKING
FOR EACH ROW
BEGIN
    IF NEW.booking_status = 'cancelled' AND OLD.booking_status = 'confirmed' THEN
        UPDATE TIME_SLOT
        SET booked_count = GREATEST(0, booked_count - OLD.number_of_persons)
        WHERE time_slot_id = OLD.time_slot_id;
    END IF;
END$$

-- Trigger 3: Block booking if slot is full (capacity check)
CREATE TRIGGER trg_check_capacity
BEFORE INSERT ON DARSHAN_BOOKING
FOR EACH ROW
BEGIN
    DECLARE available INT;
    SELECT (max_capacity - booked_count)
    INTO available
    FROM TIME_SLOT
    WHERE time_slot_id = NEW.time_slot_id;
    IF available < NEW.number_of_persons THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Not enough seats available in this time slot';
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- VIEWS
-- ============================================================

-- View: Slot availability with darshan type info
CREATE VIEW vw_slot_availability AS
SELECT
    t.time_slot_id,
    t.darshan_date,
    t.start_time,
    t.end_time,
    t.slot_type,
    t.max_capacity,
    t.booked_count,
    (t.max_capacity - t.booked_count) AS available_seats,
    dt.darshan_type_id,
    dt.darshan_name,
    dt.price
FROM TIME_SLOT t
JOIN DARSHAN_TYPE dt ON t.darshan_type_id = dt.darshan_type_id
WHERE t.darshan_date >= CURDATE();

-- View: User booking summary
CREATE VIEW vw_user_bookings AS
SELECT
    db.booking_id,
    db.booking_reference,
    db.user_id,
    db.number_of_persons,
    db.booking_type,
    db.booking_status,
    db.created_at,
    t.darshan_date,
    t.start_time,
    t.end_time,
    t.slot_type,
    dt.darshan_name,
    dt.price,
    (dt.price * db.number_of_persons) AS total_amount
FROM DARSHAN_BOOKING db
JOIN TIME_SLOT t    ON db.time_slot_id    = t.time_slot_id
JOIN DARSHAN_TYPE dt ON t.darshan_type_id = dt.darshan_type_id;

-- ============================================================
-- SAMPLE DATA
-- ============================================================

INSERT INTO DARSHAN_TYPE (darshan_name, price) VALUES
('Sarva Darshan',         0.00),
('Special Entry Darshan', 300.00),
('VIP Break Darshan',     10000.00);

INSERT INTO ACCOMMODATION (room_type, capacity, price_per_day) VALUES
('Standard Room', 2,  500.00),
('Deluxe Room',   4, 1200.00),
('Suite Room',    6, 2500.00);

INSERT INTO TIME_SLOT (darshan_type_id, darshan_date, start_time, end_time, max_capacity, slot_type) VALUES
(1, '2026-05-10', '08:00:00', '10:00:00', 200, 'indian'),
(1, '2026-05-10', '10:00:00', '12:00:00', 200, 'indian'),
(2, '2026-05-10', '12:00:00', '14:00:00', 150, 'indian'),
(2, '2026-05-11', '08:00:00', '10:00:00', 150, 'indian'),
(3, '2026-05-11', '16:00:00', '18:00:00',  50, 'indian'),
(1, '2026-05-12', '06:00:00', '08:00:00', 200, 'indian'),
(1, '2026-05-12', '08:00:00', '10:00:00', 200, 'indian'),
(2, '2026-05-12', '10:00:00', '12:00:00', 150, 'indian'),
(1, '2026-05-13', '06:00:00', '08:00:00', 200, 'nri'),
(2, '2026-05-13', '10:00:00', '12:00:00', 100, 'nri'),
(3, '2026-05-13', '14:00:00', '16:00:00',  30, 'nri'),
(1, '2026-05-14', '08:00:00', '10:00:00', 200, 'indian'),
(2, '2026-05-14', '12:00:00', '14:00:00', 150, 'indian');


