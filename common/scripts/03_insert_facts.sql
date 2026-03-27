-- ============================================================
-- Руда+ MES: Заполнение факт-таблиц тестовыми данными
-- Период: Январь 2024 — Июнь 2025
-- ============================================================

-- ============================================================
-- 1. ДОБЫЧА РУДЫ (fact_production)
-- Генерируем данные за каждую смену для каждой ПДМ и самосвала
-- с учётом выходных (меньше добыча) и сезонности
-- ============================================================

-- Добыча ПДМ на шахте "Северная" (equipment_id 1,2,3 — ПДМ, операторы 1,2,10)
-- Добыча ПДМ на шахте "Южная" (equipment_id 4,6 — ПДМ, операторы 5,6)
-- Самосвалы (equipment_id 7,8,9 — Северная, 10,11 — Южная, операторы 3,4,7)

INSERT INTO fact_production (
    date_id, shift_id, mine_id, shaft_id, equipment_id, operator_id,
    location_id, ore_grade_id,
    tons_mined, tons_transported, trips_count, distance_km, fuel_consumed_l, operating_hours
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    s.shift_id,
    eq.mine_id,
    eq.shaft_id,
    eq.equipment_id,
    eq.operator_id,
    eq.location_id,
    -- Сорт руды: ~15% высший, ~40% первый, ~35% второй, ~10% третий
    CASE
        WHEN random() < 0.15 THEN 1
        WHEN random() < 0.55 THEN 2
        WHEN random() < 0.90 THEN 3
        ELSE 4
    END,
    -- Тонны добычи: базовая + сезонный коэффициент + случайный разброс
    ROUND((
        eq.base_tons
        * (CASE WHEN EXTRACT(ISODOW FROM d) IN (6,7) THEN 0.6 ELSE 1.0 END)  -- выходные
        * (CASE EXTRACT(MONTH FROM d)::INT
               WHEN 1  THEN 0.85  -- январь — холод, праздники
               WHEN 2  THEN 0.90
               WHEN 3  THEN 0.95
               WHEN 4  THEN 1.00
               WHEN 5  THEN 1.05
               WHEN 6  THEN 1.10  -- лето — пик
               WHEN 7  THEN 1.10
               WHEN 8  THEN 1.08
               WHEN 9  THEN 1.05
               WHEN 10 THEN 1.00
               WHEN 11 THEN 0.92
               WHEN 12 THEN 0.88
           END)
        * (0.80 + random() * 0.40)  -- разброс ±20%
    )::NUMERIC, 2),
    -- Перевезено (чуть меньше добыто — потери)
    ROUND((
        eq.base_tons * 0.97
        * (CASE WHEN EXTRACT(ISODOW FROM d) IN (6,7) THEN 0.6 ELSE 1.0 END)
        * (0.80 + random() * 0.40)
    )::NUMERIC, 2),
    -- Количество рейсов
    eq.base_trips + FLOOR(random() * 4 - 2)::INT,
    -- Расстояние
    ROUND((eq.base_trips * eq.trip_dist_km * (0.9 + random() * 0.2))::NUMERIC, 2),
    -- Топливо
    ROUND((eq.base_fuel * (0.85 + random() * 0.30))::NUMERIC, 2),
    -- Отработано часов (из 12-часовой смены минус обед и простои)
    ROUND((10.0 + random() * 1.5)::NUMERIC, 2)
FROM
    generate_series('2024-01-01'::DATE, '2025-06-30'::DATE, '1 day') AS d
CROSS JOIN dim_shift s
CROSS JOIN (
    VALUES
        -- equip_id, mine_id, shaft_id, operator_id, location_id, base_tons, base_trips, trip_dist, base_fuel
        (1, 1, 3, 1,  1, 85.0,  8, 1.2, 120.0),   -- ПДМ-001, Северная, горизонт -480
        (2, 1, 3, 2,  2, 82.0,  8, 1.3, 115.0),   -- ПДМ-002, Северная, горизонт -480
        (3, 1, 4, 10, 6, 78.0,  7, 1.5, 125.0),   -- ПДМ-003, Северная, горизонт -620
        (4, 2, 7, 5, 10, 90.0,  9, 1.1, 110.0),   -- ПДМ-004, Южная, горизонт -420
        (6, 2, 7, 6, 11, 88.0,  8, 1.2, 118.0),   -- ПДМ-006, Южная, горизонт -420
        (7, 1, 3, 3,  3, 180.0, 6, 2.5, 200.0),   -- Самосвал-001, Северная
        (8, 1, 4, 4,  8, 175.0, 6, 2.8, 210.0),   -- Самосвал-002, Северная
        (10,2, 7, 7, 12, 170.0, 6, 2.2, 195.0)    -- Самосвал-004, Южная
) AS eq(equipment_id, mine_id, shaft_id, operator_id, location_id, base_tons, base_trips, trip_dist_km, base_fuel)
-- Не каждый день каждая единица работает — убираем ~5% случайно
WHERE random() > 0.05;

-- ============================================================
-- 2. ТЕЛЕМЕТРИЯ ОБОРУДОВАНИЯ (fact_equipment_telemetry)
-- Выборка каждые 15 минут для активного оборудования
-- Ограничимся одним месяцем подробно (январь 2024)
-- и ещё несколькими днями в разных месяцах
-- ============================================================

-- Январь 2024 — подробная телеметрия для ПДМ-001 (equipment_id=1)
INSERT INTO fact_equipment_telemetry (
    date_id, time_id, equipment_id, sensor_id, location_id,
    sensor_value, is_alarm, quality_flag
)
SELECT
    TO_CHAR(d::DATE, 'YYYYMMDD')::INT,
    EXTRACT(HOUR FROM d)::INT * 100 + (EXTRACT(MINUTE FROM d)::INT / 15)::INT * 15,
    1, -- equipment_id = ПДМ-001
    s.sensor_id,
    1, -- location_id
    CASE s.sensor_id
        -- S-LHD001-TEMP (sensor_id=1): температура двигателя 60-95°C
        WHEN 1 THEN ROUND((75 + random() * 20 +
            CASE WHEN EXTRACT(HOUR FROM d)::INT BETWEEN 10 AND 16 THEN 8 ELSE 0 END)::NUMERIC, 2)
        -- S-LHD001-VIB (sensor_id=2): вибрация 2-12 мм/с
        WHEN 2 THEN ROUND((5 + random() * 7)::NUMERIC, 2)
        -- S-LHD001-SPD (sensor_id=3): скорость 0-15 км/ч
        WHEN 3 THEN ROUND((random() * 15)::NUMERIC, 2)
        -- S-LHD001-LOAD (sensor_id=4): масса 0-14 т
        WHEN 4 THEN ROUND((random() * 14)::NUMERIC, 2)
        -- S-LHD001-FUEL (sensor_id=5): уровень топлива 20-100%
        WHEN 5 THEN ROUND((100 - EXTRACT(HOUR FROM d)::NUMERIC * 3.3 + random() * 5)::NUMERIC, 2)
    END,
    CASE s.sensor_id
        WHEN 1 THEN (75 + random() * 20) > 110  -- тревога при перегреве
        WHEN 2 THEN (5 + random() * 7) > 15      -- тревога при сильной вибрации
        ELSE FALSE
    END,
    CASE WHEN random() < 0.02 THEN 'SUSPECT' ELSE 'OK' END
FROM
    generate_series('2024-01-01 08:00'::TIMESTAMP, '2024-01-31 19:45'::TIMESTAMP, '15 minutes'::INTERVAL) AS d
CROSS JOIN (
    SELECT sensor_id FROM dim_sensor WHERE equipment_id = 1
) s
WHERE EXTRACT(HOUR FROM d)::INT BETWEEN 8 AND 19;  -- только дневная смена

-- Компактная телеметрия для других месяцев (первая неделя каждого квартала)
-- ПДМ-001 и Самосвал-001
INSERT INTO fact_equipment_telemetry (
    date_id, time_id, equipment_id, sensor_id, location_id,
    sensor_value, is_alarm, quality_flag
)
SELECT
    TO_CHAR(d::DATE, 'YYYYMMDD')::INT,
    EXTRACT(HOUR FROM d)::INT * 100 + (EXTRACT(MINUTE FROM d)::INT / 15)::INT * 15,
    eq.eid,
    s.sensor_id,
    eq.loc_id,
    CASE
        WHEN st.type_code = 'TEMP_ENGINE' THEN ROUND((70 + random() * 30)::NUMERIC, 2)
        WHEN st.type_code = 'VIBRATION'   THEN ROUND((3 + random() * 10)::NUMERIC, 2)
        WHEN st.type_code = 'SPEED'       THEN ROUND((random() * 18)::NUMERIC, 2)
        WHEN st.type_code = 'LOAD_WEIGHT' THEN ROUND((random() * eq.max_load)::NUMERIC, 2)
        WHEN st.type_code = 'FUEL_LEVEL'  THEN ROUND((100 - EXTRACT(HOUR FROM d)::NUMERIC * 3 + random() * 10)::NUMERIC, 2)
        WHEN st.type_code = 'OIL_PRESS'   THEN ROUND((3 + random() * 4)::NUMERIC, 2)
        WHEN st.type_code = 'RPM'         THEN ROUND((800 + random() * 1500)::NUMERIC, 0)
        ELSE ROUND((random() * 100)::NUMERIC, 2)
    END,
    FALSE,
    'OK'
FROM
    generate_series('2024-04-01 08:00'::TIMESTAMP, '2024-04-07 19:45'::TIMESTAMP, '15 minutes'::INTERVAL) AS d
CROSS JOIN (
    VALUES (1, 1, 14.0), (7, 3, 30.0)
) AS eq(eid, loc_id, max_load)
CROSS JOIN dim_sensor s
INNER JOIN dim_sensor_type st ON s.sensor_type_id = st.sensor_type_id
WHERE s.equipment_id = eq.eid
  AND EXTRACT(HOUR FROM d)::INT BETWEEN 8 AND 19;

-- Ещё один период — июль 2024
INSERT INTO fact_equipment_telemetry (
    date_id, time_id, equipment_id, sensor_id, location_id,
    sensor_value, is_alarm, quality_flag
)
SELECT
    TO_CHAR(d::DATE, 'YYYYMMDD')::INT,
    EXTRACT(HOUR FROM d)::INT * 100 + (EXTRACT(MINUTE FROM d)::INT / 15)::INT * 15,
    eq.eid,
    s.sensor_id,
    eq.loc_id,
    CASE
        WHEN st.type_code = 'TEMP_ENGINE' THEN ROUND((75 + random() * 35)::NUMERIC, 2)  -- летом жарче
        WHEN st.type_code = 'VIBRATION'   THEN ROUND((4 + random() * 12)::NUMERIC, 2)
        WHEN st.type_code = 'SPEED'       THEN ROUND((random() * 16)::NUMERIC, 2)
        WHEN st.type_code = 'LOAD_WEIGHT' THEN ROUND((random() * eq.max_load)::NUMERIC, 2)
        WHEN st.type_code = 'FUEL_LEVEL'  THEN ROUND((100 - EXTRACT(HOUR FROM d)::NUMERIC * 3.5 + random() * 8)::NUMERIC, 2)
        WHEN st.type_code = 'OIL_PRESS'   THEN ROUND((2.5 + random() * 4.5)::NUMERIC, 2)
        WHEN st.type_code = 'RPM'         THEN ROUND((900 + random() * 1400)::NUMERIC, 0)
        ELSE ROUND((random() * 100)::NUMERIC, 2)
    END,
    CASE WHEN random() < 0.03 THEN TRUE ELSE FALSE END,  -- чуть больше тревог летом
    CASE WHEN random() < 0.01 THEN 'SUSPECT' ELSE 'OK' END
FROM
    generate_series('2024-07-01 08:00'::TIMESTAMP, '2024-07-07 19:45'::TIMESTAMP, '15 minutes'::INTERVAL) AS d
CROSS JOIN (
    VALUES (1, 1, 14.0), (4, 10, 14.0), (7, 3, 30.0), (10, 12, 30.0)
) AS eq(eid, loc_id, max_load)
CROSS JOIN dim_sensor s
INNER JOIN dim_sensor_type st ON s.sensor_type_id = st.sensor_type_id
WHERE s.equipment_id = eq.eid
  AND EXTRACT(HOUR FROM d)::INT BETWEEN 8 AND 19;

-- ============================================================
-- 3. ПРОСТОИ ОБОРУДОВАНИЯ (fact_equipment_downtime)
-- Генерируем типовые простои для каждого месяца
-- ============================================================

-- Плановое ТО — раз в месяц для каждой ПДМ и самосвала (8 часов)
INSERT INTO fact_equipment_downtime (
    date_id, shift_id, equipment_id, reason_id, operator_id, location_id,
    start_time, end_time, duration_min, is_planned, comment
)
SELECT
    TO_CHAR(maint_date, 'YYYYMMDD')::INT,
    1, -- дневная смена
    eq.eid,
    1, -- Плановое ТО
    eq.oper_id,
    eq.loc_id,
    maint_date + '08:00'::TIME,
    maint_date + '16:00'::TIME,
    480.00,
    TRUE,
    'Плановое ТО по регламенту'
FROM
    generate_series('2024-01-15'::DATE, '2025-06-15'::DATE, '1 month'::INTERVAL) AS maint_date
CROSS JOIN (
    VALUES (1, 1, 1), (2, 2, 2), (3, 10, 6), (4, 5, 10), (6, 6, 11),
           (7, 3, 3), (8, 4, 8), (10, 7, 12)
) AS eq(eid, oper_id, loc_id);

-- Аварийные ремонты — случайные (2-5 на единицу за полгода)
INSERT INTO fact_equipment_downtime (
    date_id, shift_id, equipment_id, reason_id, operator_id, location_id,
    start_time, end_time, duration_min, is_planned, comment
)
VALUES
-- ПДМ-001 — аварийные
(20240208, 1, 1, 2, 1, 1, '2024-02-08 10:30', '2024-02-08 18:30', 480, FALSE, 'Разрыв гидрошланга'),
(20240315, 2, 1, 8, 1, 1, '2024-03-15 22:00', '2024-03-16 02:00', 240, FALSE, 'Перегрев двигателя, замена термостата'),
(20240520, 1, 1, 2, 1, 1, '2024-05-20 14:00', '2024-05-20 20:00', 360, FALSE, 'Отказ стартера'),
(20240901, 1, 1, 2, 1, 1, '2024-09-01 09:00', '2024-09-01 17:00', 480, FALSE, 'Поломка ковша'),
-- ПДМ-002 — аварийные
(20240122, 1, 2, 2, 2, 2, '2024-01-22 11:00', '2024-01-22 15:00', 240, FALSE, 'Утечка масла трансмиссии'),
(20240610, 2, 2, 8, 2, 2, '2024-06-10 21:00', '2024-06-11 03:00', 360, FALSE, 'Перегрев, высокая температура забоя'),
(20241105, 1, 2, 2, 2, 2, '2024-11-05 08:30', '2024-11-05 16:30', 480, FALSE, 'Разрушение подшипника'),
-- ПДМ-004 — аварийные
(20240305, 1, 4, 2, 5, 10, '2024-03-05 09:00', '2024-03-05 13:00', 240, FALSE, 'Повреждение шины'),
(20240718, 2, 4, 9, 5, 10, '2024-07-18 20:30', '2024-07-19 08:00', 690, FALSE, 'Обрушение породы, повреждение кузова'),
(20241220, 1, 4, 2, 5, 10, '2024-12-20 10:00', '2024-12-20 18:00', 480, FALSE, 'Отказ гидронасоса'),
-- Самосвал-001 — аварийные
(20240418, 1, 7, 2, 3, 3, '2024-04-18 12:00', '2024-04-18 20:00', 480, FALSE, 'Обрыв приводного ремня'),
(20240805, 1, 7, 8, 3, 3, '2024-08-05 14:00', '2024-08-05 19:00', 300, FALSE, 'Перегрев, система охлаждения'),
(20250210, 1, 7, 2, 3, 3, '2025-02-10 09:00', '2025-02-10 21:00', 720, FALSE, 'Замена ступицы колеса'),
-- Самосвал-004 — аварийные
(20240530, 2, 10, 2, 7, 12, '2024-05-30 22:00', '2024-05-31 10:00', 720, FALSE, 'Отказ тормозной системы'),
(20241015, 1, 10, 11, 7, 12, '2024-10-15 08:00', '2024-10-15 12:00', 240, FALSE, 'Перебои электроснабжения горизонта');

-- Организационные простои (ожидание погрузки/транспорта, отсутствие оператора)
INSERT INTO fact_equipment_downtime (
    date_id, shift_id, equipment_id, reason_id, operator_id, location_id,
    start_time, end_time, duration_min, is_planned, comment
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    CASE WHEN random() < 0.7 THEN 1 ELSE 2 END,
    eq.eid,
    CASE
        WHEN random() < 0.35 THEN 5  -- ожидание погрузки
        WHEN random() < 0.65 THEN 6  -- ожидание транспорта
        WHEN random() < 0.85 THEN 4  -- отсутствие оператора
        ELSE 10                       -- проветривание
    END,
    eq.oper_id,
    eq.loc_id,
    d + (8 + FLOOR(random() * 10)::INT) * INTERVAL '1 hour',
    d + (8 + FLOOR(random() * 10)::INT + 1) * INTERVAL '1 hour' + (FLOOR(random() * 60)::INT) * INTERVAL '1 minute',
    ROUND((30 + random() * 150)::NUMERIC, 2),
    FALSE,
    NULL
FROM
    generate_series('2024-01-01'::DATE, '2025-06-30'::DATE, '1 day') AS d
CROSS JOIN (
    VALUES (1, 1, 1), (2, 2, 2), (4, 5, 10), (7, 3, 3), (10, 7, 12)
) AS eq(eid, oper_id, loc_id)
WHERE random() < 0.15  -- ~15% дней есть оргпростой
  AND EXTRACT(ISODOW FROM d) NOT IN (6, 7);

-- Заправка — регулярно (каждые 3-4 дня)
INSERT INTO fact_equipment_downtime (
    date_id, shift_id, equipment_id, reason_id, operator_id, location_id,
    start_time, end_time, duration_min, is_planned, comment
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    1,  -- дневная смена
    eq.eid,
    7,  -- Заправка
    eq.oper_id,
    eq.loc_id,
    d + '12:00'::TIME,
    d + '12:30'::TIME,
    30.00,
    TRUE,
    'Плановая заправка'
FROM
    generate_series('2024-01-01'::DATE, '2025-06-30'::DATE, '3 days'::INTERVAL) AS d
CROSS JOIN (
    VALUES (1, 1, 5), (2, 2, 5), (3, 10, 9), (4, 5, 14), (6, 6, 14),
           (7, 3, 5), (8, 4, 9), (10, 7, 14)
) AS eq(eid, oper_id, loc_id)
WHERE EXTRACT(ISODOW FROM d) NOT IN (7);

-- ============================================================
-- 4. КАЧЕСТВО РУДЫ (fact_ore_quality)
-- Пробы берутся 2-4 раза в смену
-- ============================================================

INSERT INTO fact_ore_quality (
    date_id, time_id, shift_id, mine_id, shaft_id, location_id, ore_grade_id,
    sample_number, fe_content, sio2_content, al2o3_content, moisture, density, sample_weight_kg
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    (8 + sample_hour) * 100 + sample_min,
    1, -- дневная смена
    m.mine_id,
    m.shaft_id,
    m.loc_id,
    CASE
        WHEN fe_val >= 60 THEN 1  -- высший
        WHEN fe_val >= 45 THEN 2  -- первый
        WHEN fe_val >= 30 THEN 3  -- второй
        ELSE 4                     -- третий
    END,
    'PRB-' || TO_CHAR(d, 'YYYYMMDD') || '-' || m.mine_code || '-' || sample_num,
    ROUND(fe_val::NUMERIC, 2),
    ROUND((8 + random() * 15)::NUMERIC, 2),   -- SiO2: 8-23%
    ROUND((2 + random() * 6)::NUMERIC, 2),    -- Al2O3: 2-8%
    ROUND((3 + random() * 5)::NUMERIC, 2),    -- Влажность: 3-8%
    ROUND((3.2 + random() * 1.3)::NUMERIC, 3),-- Плотность: 3.2-4.5 г/см³
    ROUND((0.5 + random() * 2.5)::NUMERIC, 2) -- Масса пробы: 0.5-3.0 кг
FROM
    generate_series('2024-01-01'::DATE, '2025-06-30'::DATE, '1 day') AS d
CROSS JOIN (
    VALUES
        (1, 3, 1, 'N480'),
        (1, 4, 6, 'N620'),
        (2, 7, 10, 'S420')
) AS m(mine_id, shaft_id, loc_id, mine_code)
CROSS JOIN (
    VALUES (1, 0, 20), (2, 2, 45), (3, 5, 10)
) AS samples(sample_num, sample_hour, sample_min)
CROSS JOIN LATERAL (
    SELECT
        -- Fe содержание: в среднем ~48% с нормальным распределением
        -- Северная глубже — чуть богаче; сезонные колебания
        (42 + random() * 22
         + CASE m.mine_id WHEN 1 THEN 3 ELSE 0 END
         + CASE WHEN EXTRACT(MONTH FROM d)::INT BETWEEN 5 AND 9 THEN 2 ELSE -1 END
        ) AS fe_val
) fe_calc
WHERE EXTRACT(ISODOW FROM d) NOT IN (7)  -- воскресенье — нет проб
  AND random() > 0.05;  -- иногда пробы пропускаются

-- Ночные пробы (реже — 1-2 за смену)
INSERT INTO fact_ore_quality (
    date_id, time_id, shift_id, mine_id, shaft_id, location_id, ore_grade_id,
    sample_number, fe_content, sio2_content, al2o3_content, moisture, density, sample_weight_kg
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    2200 + FLOOR(random() * 2)::INT * 100,
    2, -- ночная смена
    m.mine_id,
    m.shaft_id,
    m.loc_id,
    CASE
        WHEN fe_val >= 60 THEN 1
        WHEN fe_val >= 45 THEN 2
        WHEN fe_val >= 30 THEN 3
        ELSE 4
    END,
    'PRB-' || TO_CHAR(d, 'YYYYMMDD') || '-' || m.mine_code || '-N' || sample_num,
    ROUND(fe_val::NUMERIC, 2),
    ROUND((9 + random() * 14)::NUMERIC, 2),
    ROUND((2.5 + random() * 5.5)::NUMERIC, 2),
    ROUND((3.5 + random() * 4.5)::NUMERIC, 2),
    ROUND((3.1 + random() * 1.4)::NUMERIC, 3),
    ROUND((0.5 + random() * 2.0)::NUMERIC, 2)
FROM
    generate_series('2024-01-01'::DATE, '2025-06-30'::DATE, '1 day') AS d
CROSS JOIN (
    VALUES
        (1, 3, 1, 'N480'),
        (2, 7, 10, 'S420')
) AS m(mine_id, shaft_id, loc_id, mine_code)
CROSS JOIN (VALUES (1), (2)) AS samples(sample_num)
CROSS JOIN LATERAL (
    SELECT (40 + random() * 24
            + CASE m.mine_id WHEN 1 THEN 3 ELSE 0 END
           ) AS fe_val
) fe_calc
WHERE EXTRACT(ISODOW FROM d) NOT IN (6, 7)  -- ночью в выходные не работаем
  AND random() > 0.15;
