-- ============================================================
-- Модуль 12. Использование операторов набора
-- Примеры на языке SQL (PostgreSQL)
-- Предприятие «Руда+»
-- ============================================================

-- ============================================================
-- 1. UNION ALL — объединение без удаления дубликатов
-- ============================================================

-- 1.1 Журнал событий оборудования: добыча + простои
SELECT
    'Добыча'      AS event_type,
    fp.date_id,
    fp.equipment_id,
    e.equipment_name,
    fp.tons_mined AS metric_value,
    'тонн'        AS unit
FROM fact_production fp
JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
WHERE fp.date_id = 20240315

UNION ALL

SELECT
    'Простой'       AS event_type,
    fd.date_id,
    fd.equipment_id,
    e.equipment_name,
    fd.duration_min AS metric_value,
    'мин.'          AS unit
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
WHERE fd.date_id = 20240315

ORDER BY equipment_name, event_type;

-- 1.2 Сводный отчёт по шахтам: несколько метрик
SELECT mine_name, metric, value
FROM (
    SELECT m.mine_name, 'Добыча (тонн)' AS metric,
           ROUND(SUM(fp.tons_mined), 0) AS value
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Простои (часы)' AS metric,
           ROUND(SUM(fd.duration_min) / 60.0, 0)
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    JOIN dim_mine m      ON e.mine_id = m.mine_id
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Среднее Fe (%)' AS metric,
           ROUND(AVG(q.fe_content), 2)
    FROM fact_ore_quality q
    JOIN dim_mine m ON q.mine_id = m.mine_id
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Тревоги (кол-во)' AS metric,
           COUNT(*)::NUMERIC
    FROM fact_equipment_telemetry t
    JOIN dim_equipment e ON t.equipment_id = e.equipment_id
    JOIN dim_mine m      ON e.mine_id = m.mine_id
    WHERE t.date_id BETWEEN 20240301 AND 20240331
      AND t.is_alarm = TRUE
    GROUP BY m.mine_name
) combined
ORDER BY mine_name, metric;

-- 1.3 Поворот сводного отчёта в «широкую» таблицу
SELECT
    mine_name,
    MAX(CASE WHEN metric = 'Добыча (тонн)'   THEN value END) AS production_tons,
    MAX(CASE WHEN metric = 'Простои (часы)'   THEN value END) AS downtime_hours,
    MAX(CASE WHEN metric = 'Среднее Fe (%)'   THEN value END) AS avg_fe_pct,
    MAX(CASE WHEN metric = 'Тревоги (кол-во)' THEN value END) AS alarm_count
FROM (
    SELECT m.mine_name, 'Добыча (тонн)' AS metric,
           ROUND(SUM(fp.tons_mined), 0) AS value
    FROM fact_production fp
    JOIN dim_mine m ON fp.mine_id = m.mine_id
    WHERE fp.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Простои (часы)',
           ROUND(SUM(fd.duration_min) / 60.0, 0)
    FROM fact_equipment_downtime fd
    JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
    JOIN dim_mine m      ON e.mine_id = m.mine_id
    WHERE fd.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Среднее Fe (%)',
           ROUND(AVG(q.fe_content), 2)
    FROM fact_ore_quality q
    JOIN dim_mine m ON q.mine_id = m.mine_id
    WHERE q.date_id BETWEEN 20240301 AND 20240331
    GROUP BY m.mine_name

    UNION ALL

    SELECT m.mine_name, 'Тревоги (кол-во)',
           COUNT(*)::NUMERIC
    FROM fact_equipment_telemetry t
    JOIN dim_equipment e ON t.equipment_id = e.equipment_id
    JOIN dim_mine m      ON e.mine_id = m.mine_id
    WHERE t.date_id BETWEEN 20240301 AND 20240331
      AND t.is_alarm = TRUE
    GROUP BY m.mine_name
) kpi
GROUP BY mine_name
ORDER BY mine_name;


-- ============================================================
-- 2. UNION — с удалением дубликатов
-- ============================================================

-- 2.1 Все активные шахты (добыча или простои)
SELECT m.mine_name
FROM fact_production fp
JOIN dim_mine m ON fp.mine_id = m.mine_id
WHERE fp.date_id BETWEEN 20240101 AND 20240331

UNION

SELECT m.mine_name
FROM fact_equipment_downtime fd
JOIN dim_equipment e ON fd.equipment_id = e.equipment_id
JOIN dim_mine m      ON e.mine_id = m.mine_id
WHERE fd.date_id BETWEEN 20240101 AND 20240331

ORDER BY mine_name;

-- 2.2 Демонстрация разницы UNION vs UNION ALL
-- UNION ALL — с дубликатами
SELECT 'UNION ALL' AS method, COUNT(*) AS row_count
FROM (
    SELECT equipment_id FROM fact_production WHERE date_id = 20240315
    UNION ALL
    SELECT equipment_id FROM fact_equipment_downtime WHERE date_id = 20240315
) x

UNION ALL

-- UNION — без дубликатов
SELECT 'UNION', COUNT(*)
FROM (
    SELECT equipment_id FROM fact_production WHERE date_id = 20240315
    UNION
    SELECT equipment_id FROM fact_equipment_downtime WHERE date_id = 20240315
) y;


-- ============================================================
-- 3. EXCEPT — разность наборов
-- ============================================================

-- 3.1 Оборудование с добычей, но без простоев
SELECT equipment_id FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331

EXCEPT

SELECT equipment_id FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240301 AND 20240331;

-- 3.2 С расшифровкой
SELECT
    e.equipment_name,
    et.type_name,
    m.mine_name
FROM dim_equipment e
JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
JOIN dim_mine m            ON e.mine_id = m.mine_id
WHERE e.equipment_id IN (
    SELECT equipment_id FROM fact_production
    WHERE date_id BETWEEN 20240301 AND 20240331

    EXCEPT

    SELECT equipment_id FROM fact_equipment_downtime
    WHERE date_id BETWEEN 20240301 AND 20240331
)
ORDER BY e.equipment_name;

-- 3.3 EXCEPT ALL — сохранение дубликатов
-- Если одно оборудование имеет 5 записей добычи и 3 записи простоев,
-- EXCEPT ALL вернёт 2 строки (5-3)
SELECT equipment_id FROM fact_production
WHERE date_id = 20240315

EXCEPT ALL

SELECT equipment_id FROM fact_equipment_downtime
WHERE date_id = 20240315;

-- 3.4 Эквивалент EXCEPT через NOT EXISTS
SELECT DISTINCT fp.equipment_id
FROM fact_production fp
WHERE fp.date_id BETWEEN 20240301 AND 20240331
  AND NOT EXISTS (
    SELECT 1
    FROM fact_equipment_downtime fd
    WHERE fd.equipment_id = fp.equipment_id
      AND fd.date_id BETWEEN 20240301 AND 20240331
);


-- ============================================================
-- 4. INTERSECT — пересечение наборов
-- ============================================================

-- 4.1 Оборудование с добычей И простоями
SELECT equipment_id FROM fact_production
WHERE date_id BETWEEN 20240301 AND 20240331

INTERSECT

SELECT equipment_id FROM fact_equipment_downtime
WHERE date_id BETWEEN 20240301 AND 20240331;

-- 4.2 Операторы-универсалы: работали и на ПДМ, и на самосвалах
SELECT
    o.last_name || ' ' || LEFT(o.first_name, 1) || '.' AS operator_name,
    o.position,
    o.qualification
FROM dim_operator o
WHERE o.operator_id IN (
    SELECT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'LHD'

    INTERSECT

    SELECT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'TRUCK'
)
ORDER BY o.last_name;

-- 4.3 Диаграмма Венна: ПДМ vs Самосвалы
WITH lhd_ops AS (
    SELECT DISTINCT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'LHD'
),
truck_ops AS (
    SELECT DISTINCT fp.operator_id
    FROM fact_production fp
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    JOIN dim_equipment_type et ON e.equipment_type_id = et.equipment_type_id
    WHERE et.type_code = 'TRUCK'
)
SELECT 'Оба типа' AS category, COUNT(*) AS cnt
FROM (SELECT operator_id FROM lhd_ops INTERSECT SELECT operator_id FROM truck_ops) x
UNION ALL
SELECT 'Только ПДМ', COUNT(*)
FROM (SELECT operator_id FROM lhd_ops EXCEPT SELECT operator_id FROM truck_ops) x
UNION ALL
SELECT 'Только самосвал', COUNT(*)
FROM (SELECT operator_id FROM truck_ops EXCEPT SELECT operator_id FROM lhd_ops) x;


-- ============================================================
-- 5. LATERAL JOIN (CROSS APPLY / OUTER APPLY)
-- ============================================================

-- 5.1 CROSS JOIN LATERAL — топ-3 записи для каждой шахты
SELECT m.mine_name, top3.*
FROM dim_mine m
CROSS JOIN LATERAL (
    SELECT
        d.full_date,
        e.equipment_name,
        fp.tons_mined
    FROM fact_production fp
    JOIN dim_date d      ON fp.date_id = d.date_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.mine_id = m.mine_id
      AND fp.date_id BETWEEN 20240101 AND 20240331
    ORDER BY fp.tons_mined DESC
    LIMIT 3
) top3
WHERE m.status = 'active'
ORDER BY m.mine_name, top3.tons_mined DESC;

-- 5.2 LEFT JOIN LATERAL — включая шахты без данных (OUTER APPLY)
SELECT m.mine_name, top3.*
FROM dim_mine m
LEFT JOIN LATERAL (
    SELECT
        d.full_date,
        e.equipment_name,
        fp.tons_mined
    FROM fact_production fp
    JOIN dim_date d      ON fp.date_id = d.date_id
    JOIN dim_equipment e ON fp.equipment_id = e.equipment_id
    WHERE fp.mine_id = m.mine_id
      AND fp.date_id BETWEEN 20240101 AND 20240331
    ORDER BY fp.tons_mined DESC
    LIMIT 3
) top3 ON TRUE
ORDER BY m.mine_name, top3.tons_mined DESC NULLS LAST;

-- 5.3 LATERAL — последнее показание для каждого датчика
SELECT
    s.sensor_code,
    st.type_name AS sensor_type,
    e.equipment_name,
    last_reading.*
FROM dim_sensor s
JOIN dim_sensor_type st ON s.sensor_type_id = st.sensor_type_id
JOIN dim_equipment e    ON s.equipment_id = e.equipment_id
LEFT JOIN LATERAL (
    SELECT
        t.date_id,
        t.time_id,
        t.sensor_value,
        t.is_alarm,
        t.quality_flag
    FROM fact_equipment_telemetry t
    WHERE t.sensor_id = s.sensor_id
    ORDER BY t.date_id DESC, t.time_id DESC
    LIMIT 1
) last_reading ON TRUE
WHERE s.status = 'active'
ORDER BY last_reading.date_id ASC NULLS FIRST;

-- 5.4 LATERAL с табличной функцией
-- (Требует создания функции из модуля 11)
SELECT m.mine_name, r.shift_name, r.operator_name, r.total_tons
FROM dim_mine m
CROSS JOIN LATERAL fn_mine_production_report(
    m.mine_id, 20240101, 20240131
) r
WHERE m.status = 'active'
ORDER BY m.mine_name, r.total_tons DESC;

-- 5.5 LATERAL для unnest массива (PostgreSQL-специфика)
-- Развернуть массив статусов и для каждого найти количество оборудования
SELECT status_name, COUNT(*) AS equipment_count
FROM UNNEST(ARRAY['active', 'maintenance', 'decommissioned']) AS status_name
LEFT JOIN LATERAL (
    SELECT equipment_id
    FROM dim_equipment
    WHERE status = status_name
) eq ON TRUE
GROUP BY status_name
ORDER BY equipment_count DESC;


-- ============================================================
-- 6. ПРИОРИТЕТ ОПЕРАТОРОВ И ПОРЯДОК ВЫПОЛНЕНИЯ
-- ============================================================

-- INTERSECT имеет более высокий приоритет, чем UNION / EXCEPT
-- Пример:
-- A UNION B INTERSECT C  ==  A UNION (B INTERSECT C)

-- Для явного порядка используйте скобки:
-- (A UNION B) INTERSECT C

-- 6.1 Демонстрация приоритета
(
    SELECT equipment_id FROM fact_production WHERE date_id = 20240315
    UNION
    SELECT equipment_id FROM fact_equipment_downtime WHERE date_id = 20240315
)
INTERSECT
SELECT equipment_id FROM dim_equipment WHERE status = 'active';
