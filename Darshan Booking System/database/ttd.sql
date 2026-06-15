-- ============================================================
--  TTD FINAL DATABASE
-- ============================================================

DROP DATABASE IF EXISTS ttd;
CREATE DATABASE ttd;
USE ttd;

-- ============================================================
-- 1. USERS
-- ============================================================
CREATE TABLE USERS (
    user_id        INT PRIMARY KEY AUTO_INCREMENT,
    name           VARCHAR(100) NOT NULL,
    email          VARCHAR(255) UNIQUE NOT NULL,
    phone_number   VARCHAR(15) NOT NULL,
    aadhar_number  VARCHAR(12) UNIQUE NULL,
    passport_number VARCHAR(20) UNIQUE NULL,
    country        VARCHAR(50) NOT NULL DEFAULT 'India',
    password       VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_status    ENUM('active','inactive','suspended') DEFAULT 'active',

    CONSTRAINT chk_user_id_required
        CHECK (aadhar_number IS NOT NULL OR passport_number IS NOT NULL),
    CONSTRAINT chk_aadhar_length
        CHECK (aadhar_number IS NULL OR CHAR_LENGTH(aadhar_number) = 12)
);

-- ============================================================
-- 2. DARSHAN_TYPE
-- ============================================================
CREATE TABLE DARSHAN_TYPE (
    darshan_type_id INT AUTO_INCREMENT PRIMARY KEY,
    darshan_name    VARCHAR(100) NOT NULL,
    price           DECIMAL(10,2) NOT NULL
);

-- ============================================================
-- 3. TIME_SLOT
-- ============================================================
CREATE TABLE TIME_SLOT (
    time_slot_id INT PRIMARY KEY AUTO_INCREMENT,
    darshan_type_id INT NOT NULL,
    darshan_date DATE NOT NULL,
    start_time   TIME NOT NULL,
    end_time     TIME NOT NULL,
    max_capacity INT NOT NULL CHECK (max_capacity > 0),
    slot_type    ENUM('indian','nri') DEFAULT 'indian',

    CONSTRAINT chk_slot_time CHECK (end_time > start_time),
    FOREIGN KEY (darshan_type_id) REFERENCES DARSHAN_TYPE(darshan_type_id)
);

-- ============================================================
-- 4. ACCOMMODATION
-- ============================================================
CREATE TABLE ACCOMMODATION (
    room_id             INT PRIMARY KEY AUTO_INCREMENT,
    room_type           VARCHAR(100) NOT NULL,
    capacity            INT NOT NULL CHECK (capacity > 0),
    price_per_day       DECIMAL(10,2) NOT NULL CHECK (price_per_day > 0),
    availability_status ENUM('available','booked','maintenance') DEFAULT 'available'
);

-- ============================================================
-- 5. DARSHAN_BOOKING
-- ============================================================
CREATE TABLE DARSHAN_BOOKING (
    booking_id        INT PRIMARY KEY AUTO_INCREMENT,
    user_id           INT NOT NULL,
    time_slot_id      INT NOT NULL,
    number_of_persons INT NOT NULL CHECK (number_of_persons > 0),
    booking_type      ENUM('indian','nri') NOT NULL,
    booking_status    ENUM('confirmed','cancelled','pending') DEFAULT 'pending',
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_slot UNIQUE (user_id, time_slot_id),

    FOREIGN KEY (user_id)      REFERENCES USERS(user_id)          ON DELETE CASCADE,
    FOREIGN KEY (time_slot_id) REFERENCES TIME_SLOT(time_slot_id) ON DELETE CASCADE
);

-- ============================================================
-- 6. PILGRIM_DETAILS
--    darshan_date + start_time stored directly so each
--    pilgrim's booked slot is visible without joins
-- ============================================================
CREATE TABLE PILGRIM_DETAILS (
    pilgrim_id      INT PRIMARY KEY AUTO_INCREMENT,
    booking_id      INT NOT NULL,
    pilgrim_name    VARCHAR(100) NOT NULL,
    age             INT NOT NULL CHECK (age > 0),
    gender          ENUM('Male','Female','Other') NOT NULL,
    aadhar_number   VARCHAR(12) NULL,
    passport_number VARCHAR(20) NULL,
    country         VARCHAR(50) NOT NULL DEFAULT 'India',
    darshan_date    DATE NOT NULL,          -- date of the booked slot
    start_time      TIME NOT NULL,          -- start time of the booked slot
    end_time        TIME NOT NULL,          -- end time of the booked slot

    CONSTRAINT chk_pilgrim_id_required
        CHECK (aadhar_number IS NOT NULL OR passport_number IS NOT NULL),
    CONSTRAINT chk_pilgrim_aadhar_length
        CHECK (aadhar_number IS NULL OR CHAR_LENGTH(aadhar_number) = 12),

    FOREIGN KEY (booking_id) REFERENCES DARSHAN_BOOKING(booking_id) ON DELETE CASCADE
);

-- ============================================================
-- 7. ROOM_BOOKING
-- ============================================================
CREATE TABLE ROOM_BOOKING (
    room_booking_id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id      INT NOT NULL,
    user_id         INT NOT NULL,
    room_id         INT NOT NULL,
    check_in_date   DATE NOT NULL,
    check_out_date  DATE NOT NULL,
    booking_status  ENUM('confirmed','cancelled','pending') DEFAULT 'pending',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_room_dates CHECK (check_out_date > check_in_date),

    FOREIGN KEY (booking_id) REFERENCES DARSHAN_BOOKING(booking_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES USERS(user_id)              ON DELETE CASCADE,
    FOREIGN KEY (room_id)    REFERENCES ACCOMMODATION(room_id)
);

-- ============================================================
-- 8. PAYMENT
-- ============================================================
CREATE TABLE PAYMENT (
    payment_id      INT PRIMARY KEY AUTO_INCREMENT,
    user_id         INT NOT NULL,
    booking_id      INT NULL,
    room_booking_id INT NULL,
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_status  ENUM('success','failed','pending') DEFAULT 'pending',
    payment_method  ENUM('upi','netbanking','debit_card','credit_card','wallet') NOT NULL,

    CONSTRAINT chk_payment_single_booking
        CHECK (
            (booking_id IS NOT NULL AND room_booking_id IS NULL) OR
            (booking_id IS NULL AND room_booking_id IS NOT NULL)
        ),

    FOREIGN KEY (user_id)         REFERENCES USERS(user_id)                    ON DELETE CASCADE,
    FOREIGN KEY (booking_id)      REFERENCES DARSHAN_BOOKING(booking_id)       ON DELETE CASCADE,
    FOREIGN KEY (room_booking_id) REFERENCES ROOM_BOOKING(room_booking_id)     ON DELETE CASCADE
);

-- ============================================================
-- 9. DONATION
-- ============================================================
CREATE TABLE DONATION (
    donation_id   INT PRIMARY KEY AUTO_INCREMENT,
    user_id       INT NOT NULL,
    amount        DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    donation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    donation_type VARCHAR(50),

    FOREIGN KEY (user_id) REFERENCES USERS(user_id) ON DELETE CASCADE
);

-- ============================================================
-- TRIGGERS
-- ============================================================
DELIMITER $$

-- Trigger 1: Block insert when slot is over capacity
CREATE TRIGGER trg_check_capacity
BEFORE INSERT ON DARSHAN_BOOKING
FOR EACH ROW
BEGIN
    DECLARE total_booked INT;
    DECLARE max_cap      INT;

    SELECT IFNULL(SUM(number_of_persons), 0)
    INTO total_booked
    FROM DARSHAN_BOOKING
    WHERE time_slot_id   = NEW.time_slot_id
      AND booking_status IN ('confirmed', 'pending');

    SELECT max_capacity
    INTO max_cap
    FROM TIME_SLOT
    WHERE time_slot_id = NEW.time_slot_id;

    IF total_booked + NEW.number_of_persons > max_cap THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Booking exceeds available capacity for this slot';
    END IF;
END$$

-- Trigger 2: Auto-fill darshan_date, start_time, end_time
--            into PILGRIM_DETAILS on every insert
CREATE TRIGGER trg_pilgrim_slot_info
BEFORE INSERT ON PILGRIM_DETAILS
FOR EACH ROW
BEGIN
    DECLARE v_date  DATE;
    DECLARE v_start TIME;
    DECLARE v_end   TIME;

    SELECT t.darshan_date, t.start_time, t.end_time
    INTO   v_date, v_start, v_end
    FROM   DARSHAN_BOOKING db
    JOIN   TIME_SLOT t ON db.time_slot_id = t.time_slot_id
    WHERE  db.booking_id = NEW.booking_id;

    SET NEW.darshan_date = v_date;
    SET NEW.start_time   = v_start;
    SET NEW.end_time     = v_end;
END$$

DELIMITER ;

-- ============================================================
-- VIEWS
-- ============================================================

-- Available seats per slot (with darshan type info)
CREATE VIEW vw_slot_availability AS
SELECT
    t.time_slot_id,
    t.darshan_date,
    t.start_time,
    t.end_time,
    t.slot_type,
    t.max_capacity,
    IFNULL(SUM(CASE WHEN db.booking_status IN ('confirmed','pending')
                    THEN db.number_of_persons ELSE 0 END), 0) AS booked_count,
    t.max_capacity - IFNULL(SUM(CASE WHEN db.booking_status IN ('confirmed','pending')
                    THEN db.number_of_persons ELSE 0 END), 0) AS available_seats,
    dt.darshan_type_id,
    dt.darshan_name,
    dt.price
FROM TIME_SLOT t
JOIN DARSHAN_TYPE dt ON t.darshan_type_id = dt.darshan_type_id
LEFT JOIN DARSHAN_BOOKING db ON t.time_slot_id = db.time_slot_id
WHERE t.darshan_date >= CURDATE()
GROUP BY t.time_slot_id;

-- Full pilgrim view (all slot info visible directly)
CREATE VIEW vw_pilgrim_booking AS
SELECT
    pd.pilgrim_id,
    pd.pilgrim_name,
    pd.age,
    pd.gender,
    pd.aadhar_number,
    pd.passport_number,
    pd.country,
    pd.darshan_date,
    pd.start_time,
    pd.end_time,
    db.booking_id,
    db.booking_type,
    db.booking_status,
    u.name       AS booked_by,
    u.email,
    u.phone_number,
    dt.darshan_name,
    dt.price
FROM PILGRIM_DETAILS pd
JOIN DARSHAN_BOOKING db ON pd.booking_id      = db.booking_id
JOIN USERS           u  ON db.user_id         = u.user_id
JOIN TIME_SLOT       t  ON db.time_slot_id    = t.time_slot_id
JOIN DARSHAN_TYPE    dt ON t.darshan_type_id  = dt.darshan_type_id;

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