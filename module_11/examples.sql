-- ============================================================
-- Модуль 11. Использование табличных выражений
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. ПРЕДСТАВЛЕНИЯ (VIEWS)
-- ============================================================

-- 1.1 Простое представление — сводка по добыче
CREATE OR REPLACE VIEW v_mine_monthly_production AS
SELECT
    m.mine_name,
    d.year,
    d.month,
    d.month_name,
    d.year_month,
    COUNT(*)              AS records_count,
    SUM(fp.tons_mined)    AS total_tons_mined,
    SUM(fp.tons_transported) AS total_tons_transported,
    SUM(fp.trips_count)   AS total_trips,
    AVG(fp.tons_mined)    AS avg_tons_per_shift,
    SUM(fp.fuel_consumed_l) AS total_fuel,
    SUM(fp.operating_hours) AS total_hours
FROM fact_production fp
JOIN dim_mine m  ON fp.mine_id = m.mine_id
JOIN dim_date d  ON fp.date_id = d.date_id
GROUP BY m.mine_name, d.year, d.month, d.month_name, d.year_month;

-- Использование VIEW
SELECT mine_name, year_month, total_tons_mined
FROM v_mine_monthly_production
WHERE year = 2024
ORDER BY mine_name, year_month;

-- 1.2 Представление для обезличивания данных
CREATE OR REPLACE VIEW v_operator_anonymous AS
SELECT
    operator_id,
    tab_number,
    SUBSTRING(last_name, 1, 1) || '.' AS last_initial,
    SUBSTRING(first_name, 1, 1) || '.' AS first_initial,
    position,
    qualification,
    mine_id,
    status
FROM dim_operator;

SELECT * FROM v_operator_anonymous LIMIT 10;

-- 1.3 Обновляемое представление с WITH CHECK OPTION
CREATE OR REPLACE VIEW v_active_equipment AS
SELECT
    equipment_id,
    equipment_name,
    inventory_number,
    equipment_type_id,
    mine_id,
    manufacturer,
    model,
    status
FROM dim_equipment
WHERE status = 'active'
WITH CHECK OPTION;

-- Проверка
SELECT COUNT(*) AS active_count FROM v_active_equipment;
SELECT COUNT(*) AS total_count FROM dim_equipment;

-- 1.4 Вложенное представление: ежедневная сводка с отклонением от средней
CREATE OR REPLACE VIEW v_daily_production AS
SELECT
    d.full_date,
    d.year_month,
    m.mine_name,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(fp.operating_hours) AS daily_hours
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
JOIN dim_mine m ON fp.mine_id = m.mine_id
GROUP BY d.full_date, d.year_month, m.mine_name;

CREATE OR REPLACE VIEW v_daily_production_with_avg AS
SELECT
    dp.*,
    AVG(dp.daily_tons) OVER (
        PARTITION BY dp.mine_name
        ORDER BY dp.full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_7d
FROM v_daily_production dp;

-- Использование
SELECT full_date, mine_name,
       ROUND(daily_tons, 0) AS tons,
       ROUND(rolling_avg_7d, 0) AS avg_7d
FROM v_daily_production_with_avg
WHERE mine_name = 'Шахта Северная'
  AND full_date BETWEEN '2024-03-01' AND '2024-03-31'
ORDER BY full_date;


-- ============================================================
-- 2. МАТЕРИАЛИЗОВАННЫЕ ПРЕДСТАВЛЕНИЯ
-- ============================================================

-- 2.1 Создание MATERIALIZED VIEW
CREATE MATERIALIZED VIEW mv_daily_ore_quality_summary AS
SELECT
    d.full_date,
    d.year_month,
    m.mine_name,
    sh.shaft_name,
    g.grade_name,
    COUNT(*)               AS samples_count,
    ROUND(AVG(q.fe_content), 2)    AS avg_fe_content,
    ROUND(MIN(q.fe_content), 2)    AS min_fe_content,
    ROUND(MAX(q.fe_content), 2)    AS max_fe_content,
    ROUND(AVG(q.sio2_content), 2)  AS avg_sio2,
    ROUND(AVG(q.moisture), 2)      AS avg_moisture
FROM fact_ore_quality q
JOIN dim_date d       ON q.date_id = d.date_id
JOIN dim_mine m       ON q.mine_id = m.mine_id
JOIN dim_shaft sh     ON q.shaft_id = sh.shaft_id
LEFT JOIN dim_ore_grade g ON q.ore_grade_id = g.ore_grade_id
GROUP BY d.full_date, d.year_month, m.mine_name, sh.shaft_name, g.grade_name;

-- Индексы для материализованного представления
CREATE INDEX idx_mv_ore_quality_date ON mv_daily_ore_quality_summary(full_date);
CREATE INDEX idx_mv_ore_quality_mine ON mv_daily_ore_quality_summary(mine_name);

-- Уникальный индекс для REFRESH CONCURRENTLY
CREATE UNIQUE INDEX idx_mv_ore_quality_uniq
ON mv_daily_ore_quality_summary(full_date, mine_name, shaft_name, COALESCE(grade_name, ''));

-- 2.2 Использование
SELECT mine_name, year_month, avg_fe_content, samples_count
FROM mv_daily_ore_quality_summary
WHERE mine_name = 'Шахта Северная'
  AND full_date >= '2024-01-01'
ORDER BY full_date;

-- 2.3 Обновление
REFRESH MATERIALIZED VIEW mv_daily_ore_quality_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_ore_quality_summary;

-- 2.4 Сравнение производительности
EXPLAIN ANALYZE
SELECT mine_name, year_month, avg_fe_content
FROM mv_daily_ore_quality_summary
WHERE mine_name = 'Шахта Северная';

EXPLAIN ANALYZE
SELECT
    m.mine_name, d.year_month,
    AVG(q.fe_content) AS avg_fe_content
FROM fact_ore_quality q
JOIN dim_date d  ON q.date_id = d.date_id
JOIN dim_mine m  ON q.mine_id = m.mine_id
WHERE m.mine_name = 'Шахта Северная'
GROUP BY m.mine_name, d.year_month;


-- ============================================================
-- 3. ПРОИЗВОДНЫЕ ТАБЛИЦЫ (DERIVED TABLES)
-- ============================================================

-- 3.1 Производная таблица для ранжирования
SELECT ranked.*
FROM (
    SELECT
        m.mine_name,
        o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
        ROUND(SUM(fp.tons_mined), 1) AS total_tons,
        ROW_NUMBER() OVER (
            PARTITION BY fp.mine_id
            ORDER BY SUM(fp.tons_mined) DESC
        ) AS rn
    FROM fact_production fp
    JOIN dim_operator o ON fp.operator_id = o.operator_id
    JOIN dim_mine m     ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id, m.mine_name, o.last_name, o.first_name
) ranked
WHERE ranked.rn <= 3
ORDER BY ranked.mine_name, ranked.rn;

-- 3.2 Вложенная производная таблица — агрегация агрегатов
SELECT
    mine_name,
    ROUND(AVG(daily_tons), 1) AS avg_daily_tons,
    ROUND(MIN(daily_tons), 1) AS min_daily_tons,
    ROUND(MAX(daily_tons), 1) AS max_daily_tons
FROM (
    SELECT
        m.mine_name,
        fp.date_id,
        SUM(fp.tons_mined) AS daily_tons
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY m.mine_name, fp.date_id
) daily_data
GROUP BY mine_name
ORDER BY avg_daily_tons DESC;

-- 3.3 Производная таблица для самосоединения
-- Сравнение добычи текущего и предыдущего месяца
SELECT
    curr.mine_name,
    curr.year_month AS current_month,
    curr.total_tons AS current_tons,
    prev.total_tons AS previous_tons,
    ROUND((curr.total_tons - prev.total_tons) / NULLIF(prev.total_tons, 0) * 100, 1)
        AS growth_pct
FROM v_mine_monthly_production curr
LEFT JOIN v_mine_monthly_production prev
    ON curr.mine_name = prev.mine_name
   AND curr.year = prev.year
   AND curr.month = prev.month + 1
WHERE curr.year = 2024
ORDER BY curr.mine_name, curr.month;


-- ============================================================
-- 4. ОБОБЩЁННЫЕ ТАБЛИЧНЫЕ ВЫРАЖЕНИЯ (CTE)
-- ============================================================

-- 4.1 Простой CTE
WITH mine_totals AS (
    SELECT
        fp.mine_id,
        SUM(fp.tons_mined)     AS total_tons,
        SUM(fp.operating_hours) AS total_hours,
        COUNT(DISTINCT fp.equipment_id) AS equipment_count
    FROM fact_production fp
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id
)
SELECT
    m.mine_name,
    ROUND(mt.total_tons, 0) AS total_tons,
    ROUND(mt.total_hours, 0) AS total_hours,
    mt.equipment_count,
    ROUND(mt.total_tons / NULLIF(mt.total_hours, 0), 2) AS tons_per_hour
FROM mine_totals mt
JOIN dim_mine m ON mt.mine_id = m.mine_id
ORDER BY total_tons DESC;

-- 4.2 Множественные CTE — добыча + простои
WITH production_summary AS (
    SELECT
        fp.mine_id,
        SUM(fp.tons_mined) AS total_tons,
        SUM(fp.operating_hours) AS work_hours,
        COUNT(DISTINCT fp.equipment_id) AS equipment_used
    FROM fact_production fp
    WHERE fp.date_id BETWEEN 20240101 AND 20240331
    GROUP BY fp.mine_id
),
downtime_summary AS (
    SELECT
        e.mine_id,
        SUM(dt.duration_min) / 60.0 AS downtime_hours,
        SUM(CASE WHEN dt.is_planned = FALSE THEN dt.duration_min ELSE 0 END) / 60.0
            AS unplanned_hours
    FROM fact_equipment_downtime dt
    JOIN dim_equipment e ON dt.equipment_id = e.equipment_id
    WHERE dt.date_id BETWEEN 20240101 AND 20240331
    GROUP BY e.mine_id
)
SELECT
    m.mine_name,
    ROUND(p.total_tons, 0)    AS total_tons,
    p.equipment_used,
    ROUND(p.work_hours, 0)    AS work_hours,
    ROUND(COALESCE(d.downtime_hours, 0), 0)  AS downtime_hours,
    ROUND(COALESCE(d.unplanned_hours, 0), 0) AS unplanned_hours,
    ROUND(p.work_hours / NULLIF(p.work_hours + COALESCE(d.downtime_hours, 0), 0) * 100, 1)
        AS availability_pct
FROM production_summary p
JOIN dim_mine m ON p.mine_id = m.mine_id
LEFT JOIN downtime_summary d ON p.mine_id = d.mine_id
ORDER BY total_tons DESC;


-- ============================================================
-- 5. ТАБЛИЧНЫЕ ФУНКЦИИ
-- ============================================================

-- 5.1 PL/pgSQL табличная функция
CREATE OR REPLACE FUNCTION fn_mine_production_report(
    p_mine_id   INT,
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (
    shift_name      VARCHAR,
    operator_name   TEXT,
    equipment_name  VARCHAR,
    total_tons      NUMERIC,
    total_trips     BIGINT,
    avg_fuel_l      NUMERIC,
    total_hours     NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.shift_name,
        (o.last_name || ' ' || LEFT(o.first_name, 1) || '.')::TEXT,
        e.equipment_name,
        ROUND(SUM(fp.tons_mined), 1),
        SUM(fp.trips_count)::BIGINT,
        ROUND(AVG(fp.fuel_consumed_l), 1),
        ROUND(SUM(fp.operating_hours), 1)
    FROM fact_production fp
    JOIN dim_shift s     ON fp.shift_id = s.shift_id
    JOIN dim_operator o  ON fp.operator_id = o.operator_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.mine_id = p_mine_id
      AND fp.date_id BETWEEN p_date_from AND p_date_to
    GROUP BY s.shift_name, o.last_name, o.first_name, e.equipment_name
    ORDER BY total_tons DESC;
END;
$$ LANGUAGE plpgsql;

-- Вызов
SELECT * FROM fn_mine_production_report(1, 20240101, 20240131);

-- 5.2 Чистая SQL-функция (инлайн-оптимизация)
CREATE OR REPLACE FUNCTION fn_downtime_summary(
    p_date_from INT,
    p_date_to   INT
)
RETURNS TABLE (
    reason_name     VARCHAR,
    category        VARCHAR,
    events_count    BIGINT,
    total_hours     NUMERIC,
    avg_duration_h  NUMERIC
) AS $$
    SELECT
        dr.reason_name,
        dr.category,
        COUNT(*),
        ROUND(SUM(dt.duration_min) / 60.0, 1),
        ROUND(AVG(dt.duration_min) / 60.0, 2)
    FROM fact_equipment_downtime dt
    JOIN dim_downtime_reason dr ON dt.reason_id = dr.reason_id
    WHERE dt.date_id BETWEEN p_date_from AND p_date_to
    GROUP BY dr.reason_name, dr.category
    ORDER BY 4 DESC;
$$ LANGUAGE sql;

SELECT * FROM fn_downtime_summary(20240101, 20240630);

-- 5.3 LATERAL JOIN с табличной функцией
SELECT m.mine_name, r.*
FROM dim_mine m
CROSS JOIN LATERAL fn_mine_production_report(
    m.mine_id, 20240101, 20240131
) r
WHERE m.status = 'active'
ORDER BY m.mine_name, r.total_tons DESC;


-- ============================================================
-- 6. РЕКУРСИВНЫЕ CTE
-- ============================================================

-- 6.1 Подготовка данных — иерархия локаций
CREATE TABLE IF NOT EXISTS dim_location_hierarchy (
    location_id     INT PRIMARY KEY,
    parent_id       INT REFERENCES dim_location_hierarchy(location_id),
    location_name   VARCHAR(200) NOT NULL,
    location_type   VARCHAR(50) NOT NULL,
    depth_level     INT
);

INSERT INTO dim_location_hierarchy VALUES
    (1, NULL, 'Шахта Северная',       'шахта',    0),
    (2, 1,    'Ствол Главный',        'ствол',    1),
    (3, 1,    'Ствол Вентиляционный', 'ствол',    1),
    (4, 2,    'Горизонт -300м',       'горизонт', 2),
    (5, 2,    'Горизонт -450м',       'горизонт', 2),
    (6, 3,    'Горизонт -300м (В)',   'горизонт', 2),
    (7, 4,    'Штрек 3-Северный',     'штрек',    3),
    (8, 4,    'Штрек 3-Южный',        'штрек',    3),
    (9, 5,    'Штрек 4-Центральный',  'штрек',    3),
    (10, 7,   'Забой 3С-1',           'забой',    4),
    (11, 7,   'Забой 3С-2',           'забой',    4),
    (12, 8,   'Забой 3Ю-1',           'забой',    4),
    (13, 9,   'Забой 4Ц-1',           'забой',    4),
    (14, 9,   'Забой 4Ц-2',           'забой',    4),
    (15, NULL, 'Шахта Южная',         'шахта',    0),
    (16, 15,  'Ствол Основной',       'ствол',    1),
    (17, 16,  'Горизонт -200м',       'горизонт', 2),
    (18, 17,  'Штрек 1-Западный',     'штрек',    3),
    (19, 18,  'Забой 1З-1',           'забой',    4),
    (20, 18,  'Забой 1З-2',           'забой',    4)
ON CONFLICT (location_id) DO NOTHING;

-- 6.2 Прямой обход: от корня вниз
WITH RECURSIVE location_tree AS (
    -- Якорь: корневые элементы (шахты)
    SELECT
        location_id,
        parent_id,
        location_name,
        location_type,
        location_name::TEXT AS full_path,
        1 AS tree_depth
    FROM dim_location_hierarchy
    WHERE parent_id IS NULL

    UNION ALL

    -- Рекурсия: все потомки
    SELECT
        child.location_id,
        child.parent_id,
        child.location_name,
        child.location_type,
        tree.full_path || ' → ' || child.location_name,
        tree.tree_depth + 1
    FROM dim_location_hierarchy child
    JOIN location_tree tree ON child.parent_id = tree.location_id
    WHERE tree.tree_depth < 10  -- защита от бесконечной рекурсии
)
SELECT
    REPEAT('  ', tree_depth - 1) || location_name AS hierarchy,
    location_type,
    full_path,
    tree_depth
FROM location_tree
ORDER BY full_path;

-- 6.3 Обратный обход: от забоя к шахте
WITH RECURSIVE path_up AS (
    SELECT location_id, parent_id, location_name, location_type, 1 AS level
    FROM dim_location_hierarchy
    WHERE location_id = 10  -- Забой 3С-1

    UNION ALL

    SELECT p.location_id, p.parent_id, p.location_name, p.location_type,
           pu.level + 1
    FROM dim_location_hierarchy p
    JOIN path_up pu ON p.location_id = pu.parent_id
)
SELECT location_name, location_type, level
FROM path_up
ORDER BY level;

-- 6.4 Генерация последовательности дат
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL '1 day'
    FROM date_series
    WHERE dt < DATE '2024-01-31'
)
SELECT dt::DATE AS calendar_date,
       EXTRACT(DOW FROM dt) AS day_of_week,
       CASE WHEN EXTRACT(DOW FROM dt) IN (0, 6) THEN 'Выходной' ELSE 'Рабочий' END AS day_type
FROM date_series;

-- 6.5 Дни без добычи для шахты
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL '1 day'
    FROM date_series
    WHERE dt < DATE '2024-01-31'
),
production_dates AS (
    SELECT DISTINCT d.full_date
    FROM fact_production fp
    JOIN dim_date d ON fp.date_id = d.date_id
    WHERE fp.mine_id = 1
      AND d.full_date BETWEEN '2024-01-01' AND '2024-01-31'
)
SELECT ds.dt::DATE AS missing_date
FROM date_series ds
LEFT JOIN production_dates pd ON ds.dt = pd.full_date
WHERE pd.full_date IS NULL
ORDER BY ds.dt;

-- 6.6 Рекурсивный CTE: нарастающий итог добычи
WITH RECURSIVE cumulative AS (
    -- Якорь: первый день
    SELECT
        d.full_date,
        SUM(fp.tons_mined) AS daily_tons,
        SUM(fp.tons_mined) AS running_total
    FROM fact_production fp
    JOIN dim_date d ON fp.date_id = d.date_id
    WHERE fp.mine_id = 1
      AND d.full_date = '2024-01-01'
    GROUP BY d.full_date
)
-- Примечание: для нарастающего итога лучше использовать SUM() OVER():
SELECT
    d.full_date,
    SUM(fp.tons_mined) AS daily_tons,
    SUM(SUM(fp.tons_mined)) OVER (ORDER BY d.full_date) AS running_total
FROM fact_production fp
JOIN dim_date d ON fp.date_id = d.date_id
WHERE fp.mine_id = 1
  AND d.full_date BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY d.full_date
ORDER BY d.full_date;


-- ============================================================
-- 7. ОЧИСТКА
-- ============================================================
-- DROP VIEW IF EXISTS v_mine_monthly_production CASCADE;
-- DROP VIEW IF EXISTS v_operator_anonymous;
-- DROP VIEW IF EXISTS v_active_equipment;
-- DROP VIEW IF EXISTS v_daily_production CASCADE;
-- DROP VIEW IF EXISTS v_daily_production_with_avg;
-- DROP MATERIALIZED VIEW IF EXISTS mv_daily_ore_quality_summary;
-- DROP FUNCTION IF EXISTS fn_mine_production_report(INT, INT, INT);
-- DROP FUNCTION IF EXISTS fn_downtime_summary(INT, INT);
-- DROP TABLE IF EXISTS dim_location_hierarchy;
