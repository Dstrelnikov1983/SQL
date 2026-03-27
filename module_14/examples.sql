-- ============================================================
-- Модуль 14: Свёртывание и наборы группировки — Примеры SQL
-- СУБД: Yandex Managed Service for PostgreSQL
-- Предприятие «Руда+» — MES-система
-- ============================================================

-- Предварительная подготовка
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- ============================================================
-- 1. GROUPING SETS — гибкие наборы группировки
-- ============================================================

-- 1.1 Базовый GROUPING SETS: несколько уровней агрегации
SELECT
    m.mine_name,
    s.shift_name,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    SUM(fp.trips_count) AS total_trips,
    COUNT(DISTINCT fp.equipment_id) AS equip_count
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY GROUPING SETS (
    (m.mine_name, s.shift_name),   -- детализация
    (m.mine_name),                  -- подитог по шахтам
    (s.shift_name),                 -- подитог по сменам
    ()                              -- общий итог
)
ORDER BY
    GROUPING(m.mine_name),
    GROUPING(s.shift_name),
    m.mine_name, s.shift_name;

-- 1.2 Функция GROUPING() — маркировка подитоговых строк
SELECT
    CASE WHEN GROUPING(m.mine_name) = 1 THEN '== ВСЕ ШАХТЫ =='
         ELSE m.mine_name END AS mine,
    CASE WHEN GROUPING(s.shift_name) = 1 THEN '== ВСЕ СМЕНЫ =='
         ELSE s.shift_name END AS shift,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    GROUPING(m.mine_name, s.shift_name) AS grouping_level
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY GROUPING SETS (
    (m.mine_name, s.shift_name),
    (m.mine_name),
    (s.shift_name),
    ()
)
ORDER BY grouping_level, mine, shift;

-- 1.3 GROUPING SETS для KPI-сводки: несколько разрезов в одном запросе
SELECT
    CASE
        WHEN GROUPING(m.mine_name) = 0 THEN 'Шахта'
        WHEN GROUPING(s.shift_name) = 0 THEN 'Смена'
        WHEN GROUPING(et.type_name) = 0 THEN 'Тип оборудования'
        ELSE 'ИТОГО'
    END AS dimension,
    COALESCE(m.mine_name, s.shift_name, et.type_name, 'Все') AS dimension_value,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    SUM(fp.trips_count) AS total_trips,
    ROUND(SUM(fp.tons_mined) / NULLIF(SUM(fp.trips_count), 0), 2) AS avg_tons_per_trip
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY GROUPING SETS (
    (m.mine_name),
    (s.shift_name),
    (et.type_name),
    ()
)
ORDER BY dimension, total_tons DESC;


-- ============================================================
-- 2. ROLLUP — иерархические итоги
-- ============================================================

-- 2.1 ROLLUP по иерархии шахта → смена
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    COALESCE(s.shift_name, '== Итого по шахте ==') AS shift,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    SUM(fp.trips_count) AS total_trips,
    ROUND(SUM(fp.fuel_consumed_l), 0) AS fuel_liters
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY ROLLUP (m.mine_name, s.shift_name)
ORDER BY
    GROUPING(m.mine_name), m.mine_name,
    GROUPING(s.shift_name), s.shift_name;

-- 2.2 ROLLUP по временной иерархии: год → квартал → месяц
SELECT
    COALESCE(d.year::TEXT, 'ИТОГО') AS year,
    COALESCE('Q' || d.quarter::TEXT, 'Итого за год') AS quarter,
    COALESCE(d.month_name, 'Итого за квартал') AS month,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    SUM(fp.trips_count) AS total_trips
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND fp.mine_id = 1
GROUP BY ROLLUP (d.year, d.quarter, d.month_name)
ORDER BY
    GROUPING(d.year), d.year,
    GROUPING(d.quarter), d.quarter,
    GROUPING(d.month_name);

-- 2.3 ROLLUP с процентом от подитога
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    COALESCE(s.shift_name, '== Итого ==') AS shift,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    ROUND(
        SUM(fp.tons_mined) * 100.0
        / NULLIF(SUM(SUM(fp.tons_mined)) OVER (
            PARTITION BY CASE WHEN GROUPING(s.shift_name) = 1 THEN NULL
                              ELSE m.mine_name END
        ), 0), 1
    ) AS pct_of_group
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY ROLLUP (m.mine_name, s.shift_name)
ORDER BY GROUPING(m.mine_name), m.mine_name,
         GROUPING(s.shift_name), s.shift_name;


-- ============================================================
-- 3. CUBE — все комбинации группировки
-- ============================================================

-- 3.1 CUBE по двум измерениям: шахта x тип оборудования
SELECT
    CASE WHEN GROUPING(m.mine_name) = 1 THEN '== ВСЕ ==' ELSE m.mine_name END AS mine,
    CASE WHEN GROUPING(et.type_name) = 1 THEN '== ВСЕ ==' ELSE et.type_name END AS equip_type,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    ROUND(AVG(fp.tons_mined), 2) AS avg_tons,
    COUNT(DISTINCT fp.equipment_id) AS equip_count
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY CUBE (m.mine_name, et.type_name)
ORDER BY
    GROUPING(m.mine_name), GROUPING(et.type_name),
    m.mine_name, et.type_name;

-- 3.2 CUBE по трём измерениям: шахта x тип x смена (8 комбинаций)
SELECT
    CASE WHEN GROUPING(m.mine_name) = 1 THEN 'Все' ELSE m.mine_name END AS mine,
    CASE WHEN GROUPING(et.type_name) = 1 THEN 'Все' ELSE et.type_name END AS equip_type,
    CASE WHEN GROUPING(s.shift_name) = 1 THEN 'Все' ELSE s.shift_name END AS shift,
    ROUND(SUM(fp.tons_mined), 0) AS total_tons,
    GROUPING(m.mine_name, et.type_name, s.shift_name) AS group_level
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_shift s ON fp.shift_id = s.shift_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY CUBE (m.mine_name, et.type_name, s.shift_name)
ORDER BY group_level, mine, equip_type, shift;


-- ============================================================
-- 4. PIVOT — условная агрегация
-- ============================================================

-- 4.1 Добыча по шахтам: месяцы как столбцы
SELECT
    m.mine_name,
    ROUND(SUM(CASE WHEN d.month = 1 THEN fp.tons_mined END), 0) AS "Январь",
    ROUND(SUM(CASE WHEN d.month = 2 THEN fp.tons_mined END), 0) AS "Февраль",
    ROUND(SUM(CASE WHEN d.month = 3 THEN fp.tons_mined END), 0) AS "Март",
    ROUND(SUM(CASE WHEN d.month = 4 THEN fp.tons_mined END), 0) AS "Апрель",
    ROUND(SUM(CASE WHEN d.month = 5 THEN fp.tons_mined END), 0) AS "Май",
    ROUND(SUM(CASE WHEN d.month = 6 THEN fp.tons_mined END), 0) AS "Июнь",
    ROUND(SUM(fp.tons_mined), 0) AS "Итого"
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND d.month <= 6
GROUP BY m.mine_name
ORDER BY m.mine_name;

-- 4.2 Матрица простоев: оборудование x причина
SELECT
    e.equipment_name,
    ROUND(SUM(CASE WHEN dr.reason_code = 'MAINT_PLAN' THEN fd.duration_min END) / 60.0, 1)
        AS "Плановое ТО",
    ROUND(SUM(CASE WHEN dr.reason_code = 'BREAKDOWN' THEN fd.duration_min END) / 60.0, 1)
        AS "Поломка",
    ROUND(SUM(CASE WHEN dr.reason_code = 'TIRE_CHANGE' THEN fd.duration_min END) / 60.0, 1)
        AS "Замена шин",
    ROUND(SUM(CASE WHEN dr.reason_code = 'NO_OPERATOR' THEN fd.duration_min END) / 60.0, 1)
        AS "Нет оператора",
    ROUND(SUM(fd.duration_min) / 60.0, 1) AS "Всего (ч)"
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_downtime_reason dr ON fd.reason_id = dr.reason_id
WHERE fd.date_id BETWEEN 20240101 AND 20240331
GROUP BY e.equipment_name
ORDER BY "Всего (ч)" DESC;

-- 4.3 PIVOT с ROLLUP: добыча по сменам + подитоги
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    ROUND(SUM(CASE WHEN fp.shift_id = 1 THEN fp.tons_mined END), 0) AS "Дневная",
    ROUND(SUM(CASE WHEN fp.shift_id = 2 THEN fp.tons_mined END), 0) AS "Ночная",
    ROUND(SUM(fp.tons_mined), 0) AS "Итого"
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
WHERE fp.date_id BETWEEN 20240101 AND 20240131
GROUP BY ROLLUP(m.mine_name)
ORDER BY GROUPING(m.mine_name), m.mine_name;


-- ============================================================
-- 5. crosstab — динамический PIVOT (расширение tablefunc)
-- ============================================================

-- 5.1 Базовый crosstab: добыча по шахтам и сменам
SELECT * FROM crosstab(
    $$
    SELECT
        m.mine_name,
        s.shift_name,
        ROUND(SUM(fp.tons_mined), 0)::TEXT
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    JOIN dim_shift s ON fp.shift_id = s.shift_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240131
    GROUP BY m.mine_name, s.shift_name
    ORDER BY m.mine_name, s.shift_name
    $$,
    $$
    SELECT DISTINCT shift_name FROM dim_shift ORDER BY shift_name
    $$
) AS ct(
    mine_name VARCHAR,
    day_shift TEXT,
    night_shift TEXT
);

-- 5.2 crosstab: качество руды по месяцам
SELECT * FROM crosstab(
    $$
    SELECT
        m.mine_name,
        d.month_name,
        ROUND(AVG(fq.fe_content), 2)::TEXT
    FROM fact_ore_quality fq
    JOIN dim_mine m ON fq.mine_id = m.mine_id
    JOIN dim_date d ON fq.date_id = d.date_id
    WHERE d.year = 2024 AND d.month <= 6
    GROUP BY m.mine_name, d.month, d.month_name
    ORDER BY m.mine_name, d.month
    $$,
    $$
    SELECT DISTINCT month_name FROM dim_date
    WHERE year = 2024 AND month <= 6
    ORDER BY month
    $$
) AS ct(
    mine_name VARCHAR,
    "Январь" TEXT,
    "Февраль" TEXT,
    "Март" TEXT,
    "Апрель" TEXT,
    "Май" TEXT,
    "Июнь" TEXT
);


-- ============================================================
-- 6. UNPIVOT — преобразование столбцов в строки
-- ============================================================

-- 6.1 UNPIVOT через LATERAL + VALUES
WITH wide_data AS (
    SELECT
        e.equipment_name,
        ROUND(SUM(fp.tons_mined), 0) AS tons,
        SUM(fp.trips_count) AS trips,
        ROUND(SUM(fp.fuel_consumed_l), 0) AS fuel_liters,
        ROUND(SUM(fp.operating_hours), 1) AS hours
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240131
    GROUP BY e.equipment_name
)
SELECT
    w.equipment_name,
    u.metric_name,
    u.metric_value
FROM wide_data w
CROSS JOIN LATERAL (
    VALUES
        ('Добыча (тонн)', w.tons::NUMERIC),
        ('Рейсы', w.trips::NUMERIC),
        ('Топливо (л)', w.fuel_liters::NUMERIC),
        ('Рабочие часы', w.hours::NUMERIC)
) AS u(metric_name, metric_value)
ORDER BY w.equipment_name, u.metric_name;

-- 6.2 UNPIVOT через UNNEST (альтернативный способ)
WITH wide_data AS (
    SELECT
        e.equipment_name,
        ROUND(SUM(fp.tons_mined), 0) AS tons,
        SUM(fp.trips_count) AS trips,
        ROUND(SUM(fp.fuel_consumed_l), 0) AS fuel
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240131
    GROUP BY e.equipment_name
)
SELECT
    equipment_name,
    metric_name,
    metric_value
FROM wide_data,
LATERAL UNNEST(
    ARRAY['Добыча', 'Рейсы', 'Топливо'],
    ARRAY[tons, trips::NUMERIC, fuel]
) AS u(metric_name, metric_value)
ORDER BY equipment_name, metric_name;


-- ============================================================
-- 7. КОМПЛЕКСНЫЕ ПРИМЕРЫ
-- ============================================================

-- 7.1 Квартальный отчёт: ROLLUP + PIVOT
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    ROUND(SUM(CASE WHEN d.month = 1 THEN fp.tons_mined END), 0) AS "Январь",
    ROUND(SUM(CASE WHEN d.month = 2 THEN fp.tons_mined END), 0) AS "Февраль",
    ROUND(SUM(CASE WHEN d.month = 3 THEN fp.tons_mined END), 0) AS "Март",
    ROUND(SUM(fp.tons_mined), 0) AS "Q1 Итого",
    -- Тренд: изменение Мар vs Янв (%)
    ROUND(
        (SUM(CASE WHEN d.month = 3 THEN fp.tons_mined END)
         - SUM(CASE WHEN d.month = 1 THEN fp.tons_mined END))
        * 100.0
        / NULLIF(SUM(CASE WHEN d.month = 1 THEN fp.tons_mined END), 0),
        1
    ) AS "Мар vs Янв (%)"
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
JOIN dim_date d ON fp.date_id = d.date_id
WHERE d.year = 2024 AND d.quarter = 1
GROUP BY ROLLUP(m.mine_name)
ORDER BY GROUPING(m.mine_name), m.mine_name;

-- 7.2 Мультиметрический отчёт: UNION ALL + ROLLUP
-- Добыча
SELECT
    COALESCE(m.mine_name, '== ИТОГО ==') AS mine,
    'Добыча (тонн)' AS metric,
    ROUND(SUM(fp.tons_mined), 0) AS value
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331
GROUP BY ROLLUP(m.mine_name)

UNION ALL

-- Простои
SELECT
    COALESCE(m.mine_name, '== ИТОГО =='),
    'Простои (часы)',
    ROUND(SUM(fd.duration_min) / 60.0, 0)
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_mine m ON e.mine_id = m.mine_id
WHERE fd.date_id BETWEEN 20240101 AND 20240331
GROUP BY ROLLUP(m.mine_name)

UNION ALL

-- Качество
SELECT
    COALESCE(m.mine_name, '== ИТОГО =='),
    'Среднее Fe (%)',
    ROUND(AVG(fq.fe_content), 2)
FROM fact_ore_quality fq
JOIN dim_mine m ON fq.mine_id = m.mine_id
WHERE fq.date_id BETWEEN 20240101 AND 20240331
GROUP BY ROLLUP(m.mine_name)

ORDER BY mine, metric;

-- 7.3 «Широкий» мультиметрический отчёт
WITH metrics AS (
    SELECT mine_name, metric, value FROM (
        SELECT m.mine_name, 'tons' AS metric, ROUND(SUM(fp.tons_mined), 0) AS value
        FROM fact_production fp JOIN dim_mine m ON fp.mine_id = m.mine_id
        WHERE fp.date_id BETWEEN 20240101 AND 20240331
        GROUP BY m.mine_name
        UNION ALL
        SELECT m.mine_name, 'downtime_h', ROUND(SUM(fd.duration_min)/60.0, 0)
        FROM fact_equipment_downtime fd
        JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
        JOIN dim_mine m ON e.mine_id = m.mine_id
        WHERE fd.date_id BETWEEN 20240101 AND 20240331
        GROUP BY m.mine_name
        UNION ALL
        SELECT m.mine_name, 'avg_fe', ROUND(AVG(fq.fe_content), 2)
        FROM fact_ore_quality fq JOIN dim_mine m ON fq.mine_id = m.mine_id
        WHERE fq.date_id BETWEEN 20240101 AND 20240331
        GROUP BY m.mine_name
    ) sub
)
SELECT
    mine_name AS "Шахта",
    MAX(CASE WHEN metric = 'tons' THEN value END) AS "Добыча (тонн)",
    MAX(CASE WHEN metric = 'downtime_h' THEN value END) AS "Простои (ч)",
    MAX(CASE WHEN metric = 'avg_fe' THEN value END) AS "Среднее Fe (%)"
FROM metrics
GROUP BY mine_name
ORDER BY mine_name;
