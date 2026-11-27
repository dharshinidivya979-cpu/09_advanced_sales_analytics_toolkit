-- =====================================================================
-- MODULE 09 : ADVANCED PL/SQL  (MySQL equivalents)
-- MINI PROJECT : Sales Analytics Toolkit
-- Mapping used in this script:
--   Records                  -> several variables loaded by SELECT ... INTO
--   Collections / VARRAY     -> JSON arrays (JSON_ARRAY)
--   Associative array        -> JSON object (JSON_OBJECT)
--   Nested table             -> TEMPORARY TABLE / JSON_TABLE
--   Dynamic SQL, EXECUTE IMMEDIATE -> PREPARE / EXECUTE / DEALLOCATE PREPARE
--   BULK COLLECT, FORALL     -> set-based INSERT ... SELECT, UPDATE, DELETE
--   Autonomous transaction   -> non-transactional (MyISAM) log table
--   Performance optimization -> INDEX + EXPLAIN
--   PL/SQL security          -> CREATE USER, GRANT EXECUTE, SQL SECURITY DEFINER
-- =====================================================================
SET SQL_SAFE_UPDATES = 0;
DROP DATABASE IF EXISTS m9_advanced_db;
CREATE DATABASE m9_advanced_db;
USE m9_advanced_db;

CREATE TABLE sales (
    sale_id    INT PRIMARY KEY AUTO_INCREMENT,
    product    VARCHAR(50) NOT NULL,
    region     VARCHAR(20) NOT NULL,
    amount     DECIMAL(10,2) NOT NULL,
    sale_date  DATE NOT NULL
);

CREATE TABLE sales_archive LIKE sales;

-- Log table that keeps its rows even when a transaction is rolled back
CREATE TABLE process_log (
    log_id    INT PRIMARY KEY AUTO_INCREMENT,
    message   VARCHAR(200),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE = MyISAM;

INSERT INTO sales (product, region, amount, sale_date) VALUES
('Laptop',  'North', 55000, '2025-03-10'),
('Mouse',   'South',   500, '2025-07-21'),
('Monitor', 'East',  12000, '2025-11-05'),
('Laptop',  'West',  54000, '2026-01-15'),
('Keyboard','North',  1500, '2026-02-18'),
('Monitor', 'South', 11500, '2026-03-02'),
('Laptop',  'East',  56000, '2026-04-09'),
('Mouse',   'West',    450, '2026-05-30');

-- ---------------------------------------------------------------------
-- 1. RECORDS : group of related variables for one row
-- ---------------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_show_record(IN p_sale_id INT)
BEGIN
    DECLARE r_product VARCHAR(50);
    DECLARE r_region  VARCHAR(20);
    DECLARE r_amount  DECIMAL(10,2);
    DECLARE r_date    DATE;

    SELECT product, region, amount, sale_date
      INTO r_product, r_region, r_amount, r_date
      FROM sales WHERE sale_id = p_sale_id;

    SELECT CONCAT(r_product, ' sold in ', r_region, ' for ', r_amount, ' on ', r_date) AS sale_record;
END$$
DELIMITER ;

CALL sp_show_record(1);

-- ---------------------------------------------------------------------
-- 2. COLLECTIONS : VARRAY, ASSOCIATIVE ARRAY, NESTED TABLE
-- ---------------------------------------------------------------------
-- VARRAY (fixed ordered list) -> JSON array, index starts at 0
SET @quarter_targets = JSON_ARRAY(100000, 120000, 90000, 150000);
SELECT JSON_LENGTH(@quarter_targets)           AS varray_size,
       JSON_EXTRACT(@quarter_targets, '$[1]')  AS second_element;

-- ASSOCIATIVE ARRAY (key -> value) -> JSON object
SET @region_target = JSON_OBJECT('North', 60000, 'South', 40000, 'East', 70000, 'West', 55000);
SELECT JSON_EXTRACT(@region_target, '$.North') AS north_target,
       JSON_KEYS(@region_target)               AS all_keys;

-- Compare actual sales with the target held in the associative array
SELECT region,
       SUM(amount) AS actual_sales,
       JSON_EXTRACT(@region_target, CONCAT('$.', region)) AS target
FROM sales
GROUP BY region;

-- Convert a collection into rows
SELECT jt.idx, jt.target_value
FROM JSON_TABLE('[100000,120000,90000,150000]', '$[*]'
        COLUMNS (idx FOR ORDINALITY, target_value INT PATH '$')) AS jt;

-- NESTED TABLE -> temporary table
CREATE TEMPORARY TABLE tmp_top_sales AS
    SELECT sale_id, product, region, amount FROM sales ORDER BY amount DESC LIMIT 3;
SELECT * FROM tmp_top_sales;
DROP TEMPORARY TABLE tmp_top_sales;

-- ---------------------------------------------------------------------
-- 3. DYNAMIC SQL + EXECUTE IMMEDIATE
-- ---------------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_sales_by_region(IN p_region VARCHAR(20))
BEGIN
    SET @dyn_sql    = 'SELECT sale_id, product, amount, sale_date FROM sales WHERE region = ? ORDER BY amount DESC LIMIT 5';
    SET @dyn_region = p_region;
    PREPARE stmt FROM @dyn_sql;
    EXECUTE stmt USING @dyn_region;        -- bind variable: safe from SQL injection
    DEALLOCATE PREPARE stmt;
END$$

-- Dynamic table name (validated first, so it is safe)
CREATE PROCEDURE sp_count_rows(IN p_table VARCHAR(64))
BEGIN
    DECLARE v_ok INT DEFAULT 0;

    SELECT COUNT(*) INTO v_ok
      FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table;

    IF v_ok = 0 THEN
        SELECT 'Invalid table name' AS message;
    ELSE
        SET @dyn_sql = CONCAT('SELECT COUNT(*) AS total_rows FROM `', p_table, '`');
        PREPARE stmt FROM @dyn_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$
DELIMITER ;

CALL sp_sales_by_region('North');
CALL sp_count_rows('sales');
CALL sp_count_rows('no_such_table');

-- Simple EXECUTE IMMEDIATE equivalent
SET @s = 'SELECT COUNT(*) AS laptop_sales FROM sales WHERE product = ''Laptop''';
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------
-- 4. BULK COLLECT / FORALL -> set-based statements (one statement, many rows)
-- ---------------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_archive_old_sales(IN p_cutoff DATE, OUT p_moved INT)
BEGIN
    START TRANSACTION;
    INSERT INTO sales_archive SELECT * FROM sales WHERE sale_date < p_cutoff;   -- BULK COLLECT + FORALL INSERT
    SET p_moved = ROW_COUNT();
    DELETE FROM sales WHERE sale_date < p_cutoff;                               -- FORALL DELETE
    COMMIT;
END$$
DELIMITER ;

CALL sp_archive_old_sales('2026-01-01', @moved);
SELECT @moved AS rows_archived;
SELECT * FROM sales_archive;
SELECT COUNT(*) AS rows_left_in_sales FROM sales;

-- Bulk update in one statement
UPDATE sales SET amount = ROUND(amount * 1.05, 2) WHERE region IN ('North', 'South');

-- ---------------------------------------------------------------------
-- 5. AUTONOMOUS TRANSACTION (emulated)
--    process_log is MyISAM, so its rows are NOT undone by ROLLBACK.
--    (MySQL shows a harmless warning about a non-transactional table.)
-- ---------------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE sp_autonomous_demo()
BEGIN
    START TRANSACTION;
    INSERT INTO process_log (message) VALUES ('Started inserting a test sale');
    INSERT INTO sales (product, region, amount, sale_date) VALUES ('Test Item', 'North', 1, CURDATE());
    INSERT INTO process_log (message) VALUES ('Rolling back the test sale');
    ROLLBACK;
    SELECT * FROM process_log;
    SELECT COUNT(*) AS test_rows_in_sales FROM sales WHERE product = 'Test Item';   -- 0
END$$
DELIMITER ;

CALL sp_autonomous_demo();

-- ---------------------------------------------------------------------
-- 6. PERFORMANCE OPTIMIZATION : bulk load + INDEX + EXPLAIN
-- ---------------------------------------------------------------------
INSERT INTO sales (product, region, amount, sale_date)
WITH RECURSIVE seq AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 1000
)
SELECT ELT(1 + MOD(n, 3), 'Laptop', 'Mouse', 'Monitor'),
       ELT(1 + MOD(n, 4), 'North', 'South', 'East', 'West'),
       100 + MOD(n * 37, 900),
       DATE_ADD('2026-01-01', INTERVAL MOD(n, 300) DAY)
FROM seq;

SELECT COUNT(*) AS total_sales_rows FROM sales;

-- Before index : look at the "type" (ALL = full scan) and "rows" columns
EXPLAIN SELECT * FROM sales WHERE region = 'North' AND sale_date >= '2026-06-01';

CREATE INDEX idx_sales_region_date ON sales (region, sale_date);

-- After index : type = range, far fewer rows scanned
EXPLAIN SELECT * FROM sales WHERE region = 'North' AND sale_date >= '2026-06-01';

-- Tips: select only needed columns, avoid functions on indexed columns in WHERE,
-- use set-based statements instead of row-by-row loops, keep transactions short.

-- ---------------------------------------------------------------------
-- 7. PL/SQL SECURITY : least privilege
-- ---------------------------------------------------------------------
CREATE VIEW v_sales_summary AS
SELECT region, COUNT(*) AS orders, SUM(amount) AS revenue
FROM sales
GROUP BY region;

DROP USER IF EXISTS 'sales_viewer'@'localhost';
CREATE USER 'sales_viewer'@'localhost' IDENTIFIED BY 'Viewer@123';

-- The user may run ONE procedure and read ONE view, nothing else.
-- The procedure runs with the owner's rights (SQL SECURITY DEFINER is the default).
GRANT EXECUTE ON PROCEDURE m9_advanced_db.sp_sales_by_region TO 'sales_viewer'@'localhost';
GRANT SELECT ON m9_advanced_db.v_sales_summary TO 'sales_viewer'@'localhost';
SHOW GRANTS FOR 'sales_viewer'@'localhost';

-- Security checklist for the video:
--  1. Use bind variables (PREPARE ... USING), never concatenate user input into SQL
--  2. Validate table/column names against information_schema before using them
--  3. Grant EXECUTE on procedures instead of direct table access
--  4. Use views to hide sensitive columns

REVOKE EXECUTE ON PROCEDURE m9_advanced_db.sp_sales_by_region FROM 'sales_viewer'@'localhost';
REVOKE SELECT ON m9_advanced_db.v_sales_summary FROM 'sales_viewer'@'localhost';
DROP USER 'sales_viewer'@'localhost';

SELECT * FROM v_sales_summary;
