-- ============================================================
-- Модуль 5. Использование DML для изменения данных
-- Скрипт создания таблиц для практических и лабораторных работ
-- Предприятие «Руда+»
-- СУБД: PostgreSQL (Yandex Managed Service for PostgreSQL)
-- ============================================================
-- ВАЖНО: Этот скрипт создаёт КОПИИ таблиц для безопасной
-- практики DML-операций. Основные таблицы не затрагиваются.
-- ============================================================

-- ============================================================
-- 0. Очистка (при повторном запуске)
-- ============================================================
DROP TABLE IF EXISTS practice_fact_production CASCADE;
DROP TABLE IF EXISTS practice_fact_telemetry CASCADE;
DROP TABLE IF EXISTS practice_fact_downtime CASCADE;
DROP TABLE IF EXISTS practice_dim_equipment CASCADE;
DROP TABLE IF EXISTS practice_dim_operator CASCADE;
DROP TABLE IF EXISTS practice_dim_downtime_reason CASCADE;
DROP TABLE IF EXISTS practice_dim_ore_grade CASCADE;
DROP TABLE IF EXISTS staging_production CASCADE;
DROP TABLE IF EXISTS staging_equipment_status CASCADE;
DROP TABLE IF EXISTS staging_telemetry CASCADE;
DROP TABLE IF EXISTS staging_downtime_reasons CASCADE;
DROP TABLE IF EXISTS practice_equipment_log CASCADE;

-- ============================================================
-- 1. Копии справочников для практики
-- ============================================================

-- Копия справочника оборудования
CREATE TABLE practice_dim_equipment AS
SELECT * FROM dim_equipment;

ALTER TABLE practice_dim_equipment
    ADD PRIMARY KEY (equipment_id);

CREATE UNIQUE INDEX idx_practice_equip_inv
    ON practice_dim_equipment(inventory_number);

-- Копия справочника операторов
CREATE TABLE practice_dim_operator AS
SELECT * FROM dim_operator;

ALTER TABLE practice_dim_operator
    ADD PRIMARY KEY (operator_id);

CREATE UNIQUE INDEX idx_practice_oper_tab
    ON practice_dim_operator(tab_number);

-- Копия справочника причин простоев
CREATE TABLE practice_dim_downtime_reason AS
SELECT * FROM dim_downtime_reason;

ALTER TABLE practice_dim_downtime_reason
    ADD PRIMARY KEY (reason_id);

CREATE UNIQUE INDEX idx_practice_reason_code
    ON practice_dim_downtime_reason(reason_code);

-- Копия справочника сортов руды
CREATE TABLE practice_dim_ore_grade AS
SELECT * FROM dim_ore_grade;

ALTER TABLE practice_dim_ore_grade
    ADD PRIMARY KEY (ore_grade_id);

CREATE UNIQUE INDEX idx_practice_grade_code
    ON practice_dim_ore_grade(grade_code);

-- ============================================================
-- 2. Копии факт-таблиц для практики
-- ============================================================

-- Копия факт-таблицы добычи (ограничение: только март 2024)
CREATE TABLE practice_fact_production AS
SELECT * FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331;

ALTER TABLE practice_fact_production
    ADD PRIMARY KEY (production_id);

-- Копия факт-таблицы телеметрии (ограничение: 1 день)
CREATE TABLE practice_fact_telemetry AS
SELECT * FROM fact_equipment_telemetry
WHERE date_id = 20240315;

ALTER TABLE practice_fact_telemetry
    ADD PRIMARY KEY (telemetry_id);

-- Копия факт-таблицы простоев (март 2024)
CREATE TABLE practice_fact_downtime AS
SELECT * FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240301 AND 20240331;

ALTER TABLE practice_fact_downtime
    ADD PRIMARY KEY (downtime_id);

-- ============================================================
-- 3. Staging-таблицы для ETL-практики
-- ============================================================

-- Staging: записи о добыче
CREATE TABLE staging_production (
    staging_id       SERIAL PRIMARY KEY,
    date_id          INT NOT NULL,
    shift_id         INT NOT NULL,
    mine_id          INT NOT NULL,
    shaft_id         INT NOT NULL,
    equipment_id     INT NOT NULL,
    operator_id      INT NOT NULL,
    location_id      INT,
    ore_grade_id     INT,
    tons_mined       NUMERIC(10,2) NOT NULL,
    tons_transported NUMERIC(10,2),
    trips_count      INT,
    distance_km      NUMERIC(8,2),
    fuel_consumed_l  NUMERIC(8,2),
    operating_hours  NUMERIC(6,2),
    is_validated     BOOLEAN DEFAULT FALSE,
    loaded_at        TIMESTAMP DEFAULT NOW()
);

-- Staging: статусы оборудования
CREATE TABLE staging_equipment_status (
    staging_id          SERIAL PRIMARY KEY,
    inventory_number    VARCHAR(50) NOT NULL,
    equipment_type_id   INT,
    mine_id             INT,
    equipment_name      VARCHAR(150),
    manufacturer        VARCHAR(150),
    model               VARCHAR(100),
    year_manufactured   INT,
    status              VARCHAR(30),
    new_status          VARCHAR(30),
    has_video_recorder  BOOLEAN,
    has_navigation      BOOLEAN,
    loaded_at           TIMESTAMP DEFAULT NOW()
);

-- Staging: телеметрия
CREATE TABLE staging_telemetry (
    staging_id     SERIAL PRIMARY KEY,
    date_id        INT NOT NULL,
    time_id        INT NOT NULL,
    equipment_id   INT NOT NULL,
    sensor_id      INT NOT NULL,
    location_id    INT,
    sensor_value   NUMERIC(14,4) NOT NULL,
    is_alarm       BOOLEAN DEFAULT FALSE,
    quality_flag   VARCHAR(10) DEFAULT 'OK',
    loaded_at      TIMESTAMP DEFAULT NOW()
);

-- Staging: причины простоев (для MERGE-практики)
CREATE TABLE staging_downtime_reasons (
    reason_name  VARCHAR(200) NOT NULL,
    reason_code  VARCHAR(20)  NOT NULL,
    category     VARCHAR(50)  NOT NULL,
    description  TEXT
);

-- ============================================================
-- 4. Таблица для логирования (INSERT ... RETURNING)
-- ============================================================

CREATE TABLE practice_equipment_log (
    log_id         SERIAL PRIMARY KEY,
    equipment_id   INT NOT NULL,
    action         VARCHAR(20) NOT NULL,  -- INSERT / UPDATE / DELETE
    old_status     VARCHAR(30),
    new_status     VARCHAR(30),
    changed_by     VARCHAR(100) DEFAULT CURRENT_USER,
    changed_at     TIMESTAMP DEFAULT NOW(),
    details        TEXT
);

-- ============================================================
-- 5. Наполнение staging-таблиц тестовыми данными
-- ============================================================

-- 5.1 Staging: новые записи о добыче (5 записей за 20 марта 2024)
INSERT INTO staging_production (
    date_id, shift_id, mine_id, shaft_id,
    equipment_id, operator_id, location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count,
    distance_km, fuel_consumed_l, operating_hours,
    is_validated
)
VALUES
    (20240320, 1, 1, 1, 1, 1, 1, 1, 125.50, 120.00, 8, 12.5, 45.2, 7.5, TRUE),
    (20240320, 1, 1, 1, 2, 2, 2, 1, 98.30,  95.00,  6, 10.2, 38.1, 7.0, TRUE),
    (20240320, 2, 1, 2, 3, 3, 3, 2, 110.00, 105.50, 7, 11.8, 42.0, 7.5, TRUE),
    (20240320, 2, 2, 3, 7, 4, 5, 2, 88.70,  85.00,  5,  9.5, 35.0, 6.5, TRUE),
    (20240320, 1, 1, 1, 4, 5, 1, 1, 45.00,  42.00,  3,  6.0, 20.0, 4.0, FALSE);

-- 5.2 Staging: обновления статусов оборудования
INSERT INTO staging_equipment_status (
    inventory_number, new_status, has_video_recorder, has_navigation
)
VALUES
    ('INV-LHD-001', 'maintenance', TRUE,  TRUE),
    ('INV-LHD-003', 'active',     TRUE,  TRUE),
    ('INV-TRK-001', 'maintenance', FALSE, TRUE),
    ('INV-NEW-001', 'active',     TRUE,  TRUE);  -- новое оборудование (нет в dim_equipment)

-- 5.3 Staging: данные телеметрии (с дубликатами и ошибочными значениями)
INSERT INTO staging_telemetry (
    date_id, time_id, equipment_id, sensor_id,
    location_id, sensor_value, is_alarm, quality_flag
)
VALUES
    (20240315, 800,  1, 1, 1, 72.5,    FALSE, 'OK'),
    (20240315, 805,  1, 1, 1, 73.1,    FALSE, 'OK'),
    (20240315, 810,  1, 1, 1, 999.99,  TRUE,  'ERROR'),  -- ошибочное значение
    (20240315, 815,  1, 2, 1, 45.2,    FALSE, 'OK'),
    (20240315, 800,  2, 3, 2, 68.0,    FALSE, 'OK'),
    (20240315, 805,  2, 3, 2, 68.5,    FALSE, 'OK'),
    (20240315, 810,  2, 4, 2, 120.3,   FALSE, 'OK'),
    (20240315, 815,  2, 4, 2, -50.0,   TRUE,  'ERROR');  -- ошибочное значение

-- 5.4 Staging: обновление причин простоев (для MERGE)
INSERT INTO staging_downtime_reasons (reason_name, reason_code, category, description)
VALUES
    ('Плановое ТО двигателя',        'ENG_MAINT',  'плановый',      'Регламентное техобслуживание двигателя'),
    ('Замена гидравлического масла',  'HYD_OIL',    'плановый',      'Плановая замена гидравлического масла'),
    ('Поломка ходовой части',         'CHASSIS_BRK', 'внеплановый',   'Внеплановый ремонт ходовой части'),
    ('Замена ковша',                  'BUCKET_RPL',  'плановый',      'Замена изношенного ковша ПДМ'),
    ('Отказ датчика навигации',       'NAV_FAIL',    'внеплановый',   'Выход из строя навигационного модуля');

-- ============================================================
-- 6. Вспомогательные таблицы для отдельных заданий
-- ============================================================

-- Таблица для примера с GENERATED ALWAYS AS IDENTITY
CREATE TABLE practice_identity_example (
    id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(100) NOT NULL,
    value NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Таблица для архивирования (DELETE ... RETURNING + CTE)
CREATE TABLE practice_archive_telemetry (
    telemetry_id   BIGINT,
    date_id        INT,
    time_id        INT,
    equipment_id   INT,
    sensor_id      INT,
    location_id    INT,
    sensor_value   NUMERIC(14,4),
    is_alarm       BOOLEAN,
    quality_flag   VARCHAR(10),
    loaded_at      TIMESTAMP,
    archived_at    TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- Готово! Теперь можно приступать к практическим и
-- лабораторным работам модуля 5.
-- ============================================================

SELECT 'Практические таблицы модуля 5 созданы успешно!' AS status,
       (SELECT COUNT(*) FROM practice_dim_equipment) AS equipment_count,
       (SELECT COUNT(*) FROM practice_fact_production) AS production_count,
       (SELECT COUNT(*) FROM staging_production) AS staging_prod_count,
       (SELECT COUNT(*) FROM staging_telemetry) AS staging_telemetry_count;
